# Bundled local Shiny app server. One generic `fs_fit_btn` handler works
# across every registered model via the registry contract (get_model(key)
# $fit/$forecast/$to_tibble) -- no per-model branching in the core pipeline,
# only in the parameter UI (see app_ui.R's conditionalPanels).

build_app_server <- function(input, output, session) {
  raw_data      <- shiny::reactiveVal(NULL)
  final_dataset <- shiny::reactiveVal(NULL)
  fitted_model    <- shiny::reactiveVal(NULL)
  comparison_result <- shiny::reactiveVal(NULL)
  comparison_forecasts <- shiny::reactiveVal(NULL)
  comparison_train     <- shiny::reactiveVal(NULL)
  generated_code    <- shiny::reactiveVal(NULL)
  # Authoritative aggregation actually used to build final_dataset().
  # updateRadioButtons() only round-trips via the client, so downstream
  # reactives must not read input$fs_date_agg directly -- it can still
  # hold the pre-correction value when dates are built from parts.
  effective_date_agg <- shiny::reactiveVal("day")

  # Icon-button source selectors (see R/ui_helpers.R) -- each just updates
  # the hidden radio behind it, so every input$fs_import_source /
  # input$fs_pop_source read below is completely unaffected. Options must
  # match icon_source_row()'s definitions in app_ui.R exactly.
  wire_icon_source(input, output, session, "fs_import_source", list(
    list(id = "fs_src_file",   value = "file",   title = "File upload (CSV / TSV / Excel)"),
    list(id = "fs_src_env",    value = "env",    title = "Global environment"),
    list(id = "fs_src_gsheet", value = "gsheet",  title = "Google Sheet"),
    list(id = "fs_src_url",    value = "url",     title = "URL"),
    list(id = "fs_src_paste",  value = "paste",   title = "Paste text")
  ))
  wire_icon_source(input, output, session, "fs_pop_source", list(
    list(id = "fs_pop_src_file", value = "file", title = "File upload"),
    list(id = "fs_pop_src_env",  value = "env",  title = "Global environment")
  ))

  # --- Import ---
  # Four sources: file upload, a data frame already in the user's global
  # environment (run_app() runs in their session, so this is genuinely
  # useful locally), a CSV URL, or pasted delimited text.
  accept_imported <- function(df, what) {
    # >= 1 column is enough: Individual Observations mode only needs a date
    # column (rows are counted, not summed), so a single-column table is
    # valid. Aggregated mode still requires a value column, enforced later
    # (Finalize Dataset) once fs_data_type is known.
    if (is.null(df) || !is.data.frame(df) || nrow(df) == 0 || ncol(df) < 1) {
      shiny::showNotification(
        paste0("Could not read ", what, ": need a table with at least 1 column and 1 row."),
        type = "error"
      )
      return(invisible(FALSE))
    }
    raw_data(df)
    cols <- names(df)
    shiny::updateSelectInput(session, "fs_date_col", choices = cols)
    shiny::updateSelectInput(session, "fs_value_col", choices = cols)
    # Part columns are optional, so each offers a blank "not used" choice.
    shiny::updateSelectInput(session, "fs_year_col", choices = cols)
    for (id in c("fs_quarter_col", "fs_month_col", "fs_day_col")) {
      shiny::updateSelectInput(session, id, choices = c("(none)" = "", cols), selected = "")
    }
    shiny::showNotification(
      sprintf("Loaded %d rows x %d columns from %s.", nrow(df), ncol(df), what),
      type = "message"
    )
    invisible(TRUE)
  }

  # Excel needs readxl, which is a Suggests dependency -- absent installs
  # get a clear instruction rather than an obscure failure.
  read_excel_file <- function(path, sheet = NULL) {
    if (!requireNamespace("readxl", quietly = TRUE)) {
      shiny::showNotification(
        "Reading Excel files requires the 'readxl' package. Install it with install.packages(\"readxl\").",
        type = "error", duration = 10
      )
      return(NULL)
    }
    as.data.frame(readxl::read_excel(path, sheet = sheet), check.names = FALSE)
  }

  is_excel_path <- function(name) grepl("\\.xlsx?$", name, ignore.case = TRUE)

  # Shared CSV/TSV/Excel reader, also handed to the holidays module so
  # movable-holiday uploads accept the same formats as the main import.
  read_table_file <- function(path, name) {
    if (is_excel_path(name)) {
      tryCatch(read_excel_file(path), error = function(e) NULL)
    } else {
      sep <- if (grepl("\\.tsv$", name, ignore.case = TRUE)) "\t" else ","
      tryCatch(utils::read.csv(path, sep = sep, check.names = FALSE), error = function(e) NULL)
    }
  }

  excel_sheets_available <- shiny::reactiveVal(NULL)

  output$fs_sheet_ui <- shiny::renderUI({
    sheets <- excel_sheets_available()
    if (is.null(sheets) || length(sheets) < 2) return(NULL)
    shiny::selectInput("fs_sheet", "Worksheet", choices = sheets)
  })

  global_env_data_frames <- function() {
    objs <- ls(envir = globalenv())
    keep <- vapply(objs, function(o) {
      is.data.frame(tryCatch(get(o, envir = globalenv()), error = function(e) NULL))
    }, logical(1))
    objs[keep]
  }

  refresh_env_choices <- function() {
    choices <- global_env_data_frames()
    shiny::updateSelectInput(
      session, "fs_env_obj",
      choices = if (length(choices)) choices else character(0)
    )
  }

  shiny::observeEvent(input$fs_import_source, {
    if (identical(input$fs_import_source, "env")) refresh_env_choices()
  })
  shiny::observeEvent(input$fs_refresh_env, refresh_env_choices())

  shiny::observeEvent(input$fs_file, {
    shiny::req(input$fs_file)
    path <- input$fs_file$datapath
    name <- input$fs_file$name

    if (is_excel_path(name)) {
      sheets <- tryCatch(
        if (requireNamespace("readxl", quietly = TRUE)) readxl::excel_sheets(path) else NULL,
        error = function(e) NULL
      )
      excel_sheets_available(sheets)
      df <- tryCatch(read_excel_file(path, sheet = if (length(sheets)) sheets[1] else NULL),
                      error = function(e) NULL)
    } else {
      excel_sheets_available(NULL)
      sep <- if (grepl("\\.tsv$", name, ignore.case = TRUE)) "\t" else ","
      df <- tryCatch(utils::read.csv(path, sep = sep, check.names = FALSE),
                      error = function(e) NULL)
    }
    accept_imported(df, name)
  })

  # Re-read when the user picks a different worksheet.
  shiny::observeEvent(input$fs_sheet, {
    shiny::req(input$fs_file, input$fs_sheet)
    if (!is_excel_path(input$fs_file$name)) return()
    df <- tryCatch(read_excel_file(input$fs_file$datapath, sheet = input$fs_sheet),
                    error = function(e) NULL)
    accept_imported(df, paste0(input$fs_file$name, " [", input$fs_sheet, "]"))
  })

  shiny::observeEvent(input$fs_load_env, {
    shiny::req(input$fs_env_obj)
    df <- tryCatch(get(input$fs_env_obj, envir = globalenv()), error = function(e) NULL)
    accept_imported(df, paste0("global environment object `", input$fs_env_obj, "`"))
  })

  shiny::observeEvent(input$fs_load_url, {
    shiny::req(input$fs_url)
    df <- tryCatch(utils::read.csv(trimws(input$fs_url), check.names = FALSE),
                    error = function(e) NULL)
    accept_imported(df, "that URL")
  })

  # --- Population table (for incidence rather than absolute values) ---
  pop_data <- shiny::reactiveVal(NULL)

  accept_population <- function(df, what) {
    if (is.null(df) || !is.data.frame(df) || nrow(df) == 0 || ncol(df) < 2) {
      shiny::showNotification(paste0("Could not read population data from ", what, "."),
                               type = "error")
      return(invisible(FALSE))
    }
    pop_data(df)
    shiny::updateSelectInput(session, "fs_pop_date_col", choices = names(df))
    shiny::updateSelectInput(session, "fs_pop_value_col", choices = names(df))
    shiny::showNotification(sprintf("Loaded population table (%d rows) from %s.", nrow(df), what),
                             type = "message")
    invisible(TRUE)
  }

  shiny::observeEvent(input$fs_pop_file, {
    shiny::req(input$fs_pop_file)
    name <- input$fs_pop_file$name
    df <- if (is_excel_path(name)) {
      tryCatch(read_excel_file(input$fs_pop_file$datapath), error = function(e) NULL)
    } else {
      sep <- if (grepl("\\.tsv$", name, ignore.case = TRUE)) "\t" else ","
      tryCatch(utils::read.csv(input$fs_pop_file$datapath, sep = sep, check.names = FALSE),
                error = function(e) NULL)
    }
    accept_population(df, name)
  })

  shiny::observeEvent(input$fs_pop_source, {
    if (identical(input$fs_pop_source, "env")) {
      shiny::updateSelectInput(session, "fs_pop_env_obj", choices = global_env_data_frames())
    }
  })

  shiny::observeEvent(input$fs_load_pop_env, {
    shiny::req(input$fs_pop_env_obj)
    df <- tryCatch(get(input$fs_pop_env_obj, envir = globalenv()), error = function(e) NULL)
    accept_population(df, paste0("`", input$fs_pop_env_obj, "`"))
  })

  output$fs_pop_preview <- shiny::renderTable({
    shiny::req(pop_data())
    utils::head(pop_data(), 3)
  })

  shiny::observeEvent(input$fs_load_gsheet, {
    shiny::req(input$fs_gsheet_url)
    df <- tryCatch(
      read_google_sheet(input$fs_gsheet_url, gid = input$fs_gsheet_gid),
      error = function(e) {
        shiny::showNotification(paste("Google Sheets:", conditionMessage(e)),
                                 type = "error", duration = 10)
        NULL
      }
    )
    if (!is.null(df)) {
      accept_imported(df, "that Google Sheet")
    } else if (nzchar(trimws(input$fs_gsheet_url))) {
      shiny::showNotification(
        "Could not fetch that sheet. Check it is shared as \"Anyone with the link can view\".",
        type = "error", duration = 10
      )
    }
  })

  shiny::observeEvent(input$fs_load_paste, {
    shiny::req(input$fs_paste)
    df <- tryCatch(
      utils::read.csv(text = input$fs_paste, sep = input$fs_paste_sep, check.names = FALSE),
      error = function(e) NULL
    )
    accept_imported(df, "pasted text")
  })

  # Keep the effective aggregation in step with manual changes; the
  # finalize handler below may override it when dates come from parts.
  shiny::observeEvent(input$fs_date_agg, {
    shiny::req(input$fs_date_agg)
    effective_date_agg(input$fs_date_agg)
  })

  shiny::observeEvent(input$fs_finalize_data, {
    data_type <- or_default(input$fs_data_type, "agg")
    shiny::req(raw_data())
    if (identical(data_type, "agg")) shiny::req(input$fs_value_col)

    result <- tryCatch({
      df <- raw_data()
      date_col <- input$fs_date_col
      date_agg <- input$fs_date_agg

      if (identical(input$fs_date_mode, "parts")) {
        parts <- compose_date_parts(
          df,
          year_col    = input$fs_year_col,
          quarter_col = input$fs_quarter_col,
          month_col   = input$fs_month_col,
          day_col     = input$fs_day_col
        )
        # Aggregate at the finest part supplied: Year+Quarter -> quarterly,
        # Year+Month -> monthly, and so on. Anything coarser the user asks
        # for is still honoured; finer is not meaningful, so clamp to it.
        rank <- c(day = 1, month = 2, quarter = 3, year = 4)
        if (is.na(rank[date_agg]) || rank[date_agg] < rank[parts$granularity]) {
          date_agg <- parts$granularity
          shiny::updateRadioButtons(session, "fs_date_agg", selected = date_agg)
          shiny::showNotification(
            paste0("Aggregation set to ", date_agg,
                   " -- the finest granularity available from the selected date columns."),
            type = "message"
          )
        }
        df[[".fs_composed_date"]] <- parts$ds
        date_col <- ".fs_composed_date"
      } else {
        shiny::req(date_col)
      }

      if (identical(data_type, "agg") && identical(date_col, input$fs_value_col)) {
        stop("The Value column and the Date column cannot be the same. ",
             "Pick the column holding the measurement you want to forecast.", call. = FALSE)
      }

      use_pop <- isTRUE(input$fs_use_population) && !is.null(pop_data()) &&
        !is.null(input$fs_pop_date_col) && nzchar(input$fs_pop_date_col) &&
        !is.null(input$fs_pop_value_col) && nzchar(input$fs_pop_value_col)

      if (isTRUE(input$fs_use_population) && !use_pop) {
        stop("Population normalization is enabled but the population table or its ",
             "key/value columns are not set.", call. = FALSE)
      }

      if (identical(data_type, "individual")) {
        # One row per event -- process_uploaded_data() already floors each
        # event's date to the period and counts, so there is nothing left
        # to collapse (unlike "agg" mode, where the raw rows can still carry
        # several rows per period).
        collapsed <- process_uploaded_data(
          df, type = "individual", date_col = date_col, date_agg = date_agg
        )
      } else {
        # Stage 1: raw counts only. Population is deliberately NOT applied
        # here -- normalizing per row and then summing would add rates
        # together. The hosted app splits these stages for the same reason.
        processed <- process_uploaded_data(
          df, type = "agg", date_col = date_col,
          value_col = input$fs_value_col, date_agg = date_agg
        )

        # Stage 2: collapse rows sharing a period (e.g. one row per district
        # per quarter) -- without this the series carries repeated ds values.
        collapse_fun <- or_default(input$fs_collapse_fun, "sum")
        dupes <- count_duplicate_periods(processed, date_agg)
        collapsed <- collapse_to_period(processed, date_agg, fun = collapse_fun)
        if (dupes > 0 && !identical(collapse_fun, "none")) {
          shiny::showNotification(
            sprintf("Combined %d rows sharing a period using %s -- %d periods remain.",
                     dupes, collapse_fun, nrow(collapsed)),
            type = "message", duration = 8
          )
        }
      }

      # Stage 3: now that each period holds one total, convert to incidence.
      if (use_pop) {
        collapsed <- process_uploaded_data(
          as.data.frame(collapsed), type = "agg", date_col = "ds", value_col = "y",
          date_agg       = date_agg,
          pop_df         = pop_data(),
          pop_date_col   = input$fs_pop_date_col,
          pop_value_col  = input$fs_pop_value_col,
          unit_divisor   = or_default(input$fs_unit_scale, 1),
          pop_multiplier = or_default(input$fs_pop_multiplier, 1),
          pop_freq       = input$fs_pop_freq
        )
        if (nrow(collapsed) == 0) {
          stop("Population normalization produced no rows -- the population keys ",
               "did not match any period in the data. Check the key column ",
               "(a year like 2021, or a date) against your aggregation.", call. = FALSE)
        }
        shiny::showNotification(
          sprintf("Normalized by population: %d periods of incidence.", nrow(collapsed)),
          type = "message", duration = 8
        )
      }

      list(data = collapsed, date_agg = date_agg)
    }, error = function(e) {
      shiny::showNotification(paste("Error:", e$message), type = "error")
      NULL
    })

    if (is.null(result)) {
      final_dataset(NULL)
    } else {
      effective_date_agg(result$date_agg)
      final_dataset(result$data)
    }
  })

  output$fs_data_preview <- shiny::renderTable({
    shiny::req(final_dataset())
    df <- final_dataset()
    if (nrow(df) == 0) return(data.frame(Message = "No rows to preview."))
    df$ds <- format(df$ds, "%Y-%m-%d")
    utils::head(df, 5)
  })

  output$fs_recommendation <- shiny::renderTable({
    shiny::req(final_dataset())
    df <- final_dataset()
    if (nrow(df) < 4) return(data.frame(Message = "Finalize a dataset with a few more rows to see a recommendation."))
    analysis <- tryCatch(analyze_series(df, effective_date_agg()), error = function(e) NULL)
    if (is.null(analysis)) return(data.frame(Message = "Could not analyze this dataset."))
    holidays_configured <- !is.null(final_holidays()) && nrow(final_holidays()) > 0
    ranked <- recommend_model(analysis, holidays_configured = holidays_configured)
    out <- ranked[, c("model", "score", "reason")]
    out$suggested <- suggest_parameters_for(analysis, ranked$key)
    names(out) <- c("Model", "Score", "Why", "Suggested settings")
    out$Score <- round(out$Score, 2)
    out
  })

  # --- Holidays ---
  # The full holiday system (Sundays, fixed catalog, movable-holiday file
  # upload, manual entry, relabel/remove, per-holiday windows and the
  # consistency check) lives in R/app_holidays.R.
  holiday_state <- holidays_server_logic(
    input, output, session,
    final_dataset   = final_dataset,
    read_table_file = read_table_file
  )
  combined_holidays <- holiday_state$compiled
  final_holidays    <- holiday_state$final

  # --- Model ---
  output$fs_model_choice_ui <- shiny::renderUI({
    models <- list_models(available_only = TRUE)
    choices <- setNames(vapply(models, function(m) m$key, ""), vapply(models, function(m) m$label, ""))
    shiny::selectInput("fs_model_choice", "Model", choices = choices)
  })

  output$fs_compare_choices_ui <- shiny::renderUI({
    models <- list_models(available_only = TRUE)
    choices <- setNames(vapply(models, function(m) m$key, ""), vapply(models, function(m) m$label, ""))
    shiny::checkboxGroupInput("fs_compare_choices", NULL, choices = choices)
  })

  output$fs_holiday_note <- shiny::renderUI({
    shiny::req(input$fs_model_choice)
    entry <- tryCatch(get_model(input$fs_model_choice), error = function(e) NULL)
    if (is.null(entry) || isTRUE(entry$supports_holidays)) return(NULL)
    shiny::div(style = "color:#7a5c00; background-color:#fff3cd; padding:8px; border-radius:4px;",
               holiday_limitation_note(entry$label))
  })

  train_test_split <- function() {
    df <- final_dataset()
    test_cutoff <- lubridate::`%m-%`(max(df$ds), months(input$fs_test_months))
    list(train = df[df$ds <= test_cutoff, ], test = df[df$ds > test_cutoff, ])
  }

  # Numeric inputs are normally always present (conditionalPanel hides
  # widgets but still instantiates them); default anyway so a NULL can
  # never reach Prophet's Stan backend, where it surfaces as an opaque
  # "variable does not exist" error rather than anything actionable.
  or_default <- function(x, default) {
    if (is.null(x) || length(x) != 1 || is.na(x)) default else x
  }

  build_fit_args <- function(model_key, train_df) {
    args <- list(train_df = train_df, date_agg = effective_date_agg())
    if (model_key == "prophet") {
      args <- c(args, list(
        holidays_df = final_holidays(),
        cp = or_default(input$fs_cp, 0.05),
        season = or_default(input$fs_season, 10),
        holiday = or_default(input$fs_holiday_prior, 5),
        exclude_sundays = isTRUE(input$fs_exclude_sundays),
        yearly = isTRUE(input$fs_yearly), weekly = isTRUE(input$fs_weekly), daily = isTRUE(input$fs_daily)
      ))
    } else if (model_key %in% c("arima", "sarima")) {
      auto <- identical(input$fs_arima_mode, "auto")
      args <- c(args, list(
        auto = auto,
        order = if (!auto) c(input$fs_p, input$fs_d, input$fs_q) else NULL,
        seasonal_order = if (!auto && model_key == "sarima") c(input$fs_P, input$fs_D, input$fs_Q) else NULL
      ))
    }
    args
  }

  # Scalar (non-data) args used for the "Show Code" panel -- mirrors
  # build_fit_args() but omits train_df/date_agg/holidays_df, which the
  # generated snippet references as bare variable names instead of
  # deparsing (see R/code_gen.R).
  scalar_fit_args_for_code <- function(model_key) {
    if (model_key == "prophet") {
      list(
        cp = input$fs_cp, season = input$fs_season, holiday = input$fs_holiday_prior,
        exclude_sundays = isTRUE(input$fs_exclude_sundays),
        yearly = isTRUE(input$fs_yearly), weekly = isTRUE(input$fs_weekly), daily = isTRUE(input$fs_daily)
      )
    } else if (model_key %in% c("arima", "sarima")) {
      auto <- identical(input$fs_arima_mode, "auto")
      args <- list(auto = auto)
      if (!auto) {
        args$order <- c(input$fs_p, input$fs_d, input$fs_q)
        if (model_key == "sarima") args$seasonal_order <- c(input$fs_P, input$fs_D, input$fs_Q)
      }
      args
    } else {
      list()
    }
  }

  shiny::observeEvent(input$fs_fit_btn, {
    shiny::req(final_dataset(), input$fs_model_choice)
    split <- train_test_split()
    horizon <- convert_months_to_horizon(input$fs_horizon_months, effective_date_agg())
    entry <- get_model(input$fs_model_choice)

    result <- tryCatch({
      model_obj <- do.call(entry$fit, build_fit_args(input$fs_model_choice, split$train))
      fc_raw <- entry$forecast(model_obj, horizon)
      fc_tib <- entry$to_tibble(fc_raw, split$test)
      list(model_obj = model_obj, fc_raw = fc_raw, fc_tib = fc_tib,
           train = split$train, test = split$test, key = input$fs_model_choice)
    }, error = function(e) {
      shiny::showNotification(paste("Fit failed:", e$message), type = "error")
      NULL
    })

    fitted_model(result)

    if (!is.null(result)) {
      generated_code(build_fit_code(
        model_key = input$fs_model_choice,
        date_agg = effective_date_agg(),
        scalar_args = scalar_fit_args_for_code(input$fs_model_choice),
        uses_holidays = identical(input$fs_model_choice, "prophet"),
        horizon = horizon
      ))
    }
  })

  output$fs_forecast_plot <- plotly::renderPlotly({
    shiny::validate(shiny::need(fitted_model(), "Fit a model to see results here."))
    fm <- fitted_model()
    entry <- get_model(fm$key)
    subtitle <- if (!is.null(entry$annotate)) entry$annotate(fm$model_obj) else NULL
    # Only Prophet's raw forecast() output is a data.frame with the richer
    # trend/holidays columns plot_forecast_generic() can use; the
    # forecast-package models (ARIMA/SARIMA/ETS/TBATS/NNETAR/Holt-Winters)
    # return a `forecast`-class S3 object instead, so fall back to the
    # already-standardized ds/yhat tibble for those.
    plot_input <- if (is.data.frame(fm$fc_raw)) fm$fc_raw else fm$fc_tib
    plot_forecast_generic(plot_input, train_df = fm$train, model_obj = fm$model_obj,
                           subtitle = subtitle, show_holidays = isTRUE(entry$supports_holidays))
  })

  output$fs_metrics_table <- DT::renderDT({
    shiny::validate(shiny::need(fitted_model(), "Fit a model to see results here."))
    fm <- fitted_model()
    m <- compute_multi_window_metrics(fm$fc_tib, fm$train, fm$test, effective_date_agg())
    shiny::validate(shiny::need(nrow(m) > 0, "Not enough data to score this forecast."))
    wide <- tidyr::pivot_wider(m, names_from = "Metric", values_from = "Value")
    DT::datatable(wide, options = list(dom = "t", scrollX = TRUE), rownames = FALSE)
  })

  shiny::observeEvent(input$fs_compare_btn, {
    shiny::req(final_dataset(), input$fs_compare_choices)
    split <- train_test_split()
    horizon <- convert_months_to_horizon(input$fs_horizon_months, effective_date_agg())

    # Keep each model's forecast, not just its metrics, so the comparison
    # can be plotted as well as tabulated.
    runs <- lapply(input$fs_compare_choices, function(key) {
      entry <- get_model(key)
      tryCatch({
        model_obj <- do.call(entry$fit, build_fit_args(key, split$train))
        fc_raw <- entry$forecast(model_obj, horizon)
        fc_tib <- entry$to_tibble(fc_raw, split$test)
        list(label = entry$label,
             forecast = fc_tib,
             metrics = safe_compute_metrics(fc_tib, split$test, label = entry$label))
      }, error = function(e) {
        shiny::showNotification(paste0(entry$label, " failed: ", conditionMessage(e)),
                                 type = "warning")
        list(label = entry$label,
             forecast = NULL,
             metrics = tibble::tibble(Set = entry$label,
                                       Metric = c("MASE", "sMAPE (%)", "RMSE"), Value = NA))
      })
    })

    forecasts <- stats::setNames(lapply(runs, `[[`, "forecast"), vapply(runs, `[[`, "", "label"))
    comparison_forecasts(forecasts)
    comparison_train(split$train)
    comparison_result(dplyr::bind_rows(lapply(runs, `[[`, "metrics")))
    generated_code(build_comparison_code(input$fs_compare_choices, effective_date_agg(), horizon))
  })

  output$fs_comparison_plot <- plotly::renderPlotly({
    shiny::validate(shiny::need(comparison_forecasts(),
                                 "Select models above and click Compare to overlay their forecasts."))
    fcs <- comparison_forecasts()
    fcs <- fcs[!vapply(fcs, is.null, logical(1))]
    shiny::validate(shiny::need(length(fcs) > 0, "No model produced a forecast to plot."))
    plot_model_comparison(fcs, train_df = comparison_train())
  })

  output$fs_comparison_table <- DT::renderDT({
    shiny::validate(shiny::need(comparison_result(), "Select models above and click Compare."))
    wide <- tidyr::pivot_wider(comparison_result(), names_from = "Set", values_from = "Value")
    DT::datatable(wide, options = list(dom = "t", scrollX = TRUE))
  })

  # --- Show Code (esquisse-style) ---
  output$fs_generated_code <- shiny::renderText({
    shiny::validate(shiny::need(generated_code(), "Fit a model or run a comparison to see the equivalent R code here."))
    generated_code()
  })

  output$fs_download_code <- shiny::downloadHandler(
    filename = function() paste0("forecastsuite_code_", Sys.Date(), ".R"),
    content = function(file) {
      writeLines(generated_code(), file)
    }
  )
}
