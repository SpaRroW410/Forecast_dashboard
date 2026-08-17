# Bundled local Shiny app server. One generic `fs_fit_btn` handler works
# across every registered model via the registry contract (get_model(key)
# $fit/$forecast/$to_tibble) -- no per-model branching in the core pipeline,
# only in the parameter UI (see app_ui.R's conditionalPanels).

build_app_server <- function(input, output, session) {
  raw_data      <- shiny::reactiveVal(NULL)
  final_dataset <- shiny::reactiveVal(NULL)
  manual_holidays <- shiny::reactiveVal(tibble::tibble(ds = as.Date(character()), holiday = character()))
  final_holidays  <- shiny::reactiveVal(NULL)
  fitted_model    <- shiny::reactiveVal(NULL)
  comparison_result <- shiny::reactiveVal(NULL)
  generated_code    <- shiny::reactiveVal(NULL)

  # --- Import ---
  shiny::observeEvent(input$fs_file, {
    shiny::req(input$fs_file)
    df <- tryCatch(utils::read.csv(input$fs_file$datapath), error = function(e) NULL)
    if (is.null(df)) {
      shiny::showNotification("Could not read that CSV.", type = "error")
      return()
    }
    raw_data(df)
    shiny::updateSelectInput(session, "fs_date_col", choices = names(df))
    shiny::updateSelectInput(session, "fs_value_col", choices = names(df))
  })

  shiny::observeEvent(input$fs_finalize_data, {
    shiny::req(raw_data(), input$fs_date_col, input$fs_value_col)
    result <- tryCatch(
      process_uploaded_data(raw_data(), type = "agg", date_col = input$fs_date_col,
                             value_col = input$fs_value_col, date_agg = input$fs_date_agg),
      error = function(e) {
        shiny::showNotification(paste("Error:", e$message), type = "error")
        NULL
      }
    )
    final_dataset(result)
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
    analysis <- tryCatch(analyze_series(df, input$fs_date_agg), error = function(e) NULL)
    if (is.null(analysis)) return(data.frame(Message = "Could not analyze this dataset."))
    holidays_configured <- !is.null(final_holidays()) && nrow(final_holidays()) > 0
    ranked <- recommend_model(analysis, holidays_configured = holidays_configured)
    out <- ranked[, c("model", "score", "reason")]
    names(out) <- c("Model", "Score", "Why")
    out$Score <- round(out$Score, 2)
    out
  })

  # --- Holidays ---
  shiny::observeEvent(input$fs_add_manual_holiday, {
    shiny::req(input$fs_manual_holiday_date, nzchar(input$fs_manual_holiday_label))
    years <- if (!is.null(final_dataset()) && nrow(final_dataset()) > 0) {
      unique(lubridate::year(final_dataset()$ds))
    } else {
      lubridate::year(input$fs_manual_holiday_date)
    }
    type <- if (isTRUE(input$fs_manual_holiday_recurring)) "fixed" else "single"
    manual_holidays(apply_manual_entry(manual_holidays(), input$fs_manual_holiday_date,
                                        input$fs_manual_holiday_label, type, years))
  })

  shiny::observeEvent(input$fs_clear_holidays, {
    manual_holidays(tibble::tibble(ds = as.Date(character()), holiday = character()))
  })

  combined_holidays <- shiny::reactive({
    parts <- list(manual_holidays())
    if (isTRUE(input$fs_use_sundays) && !is.null(final_dataset()) && nrow(final_dataset()) > 0) {
      yrs <- range(lubridate::year(final_dataset()$ds))
      parts <- c(parts, list(generate_sundays(yrs[1], yrs[2])))
    }
    dplyr::distinct(dplyr::bind_rows(parts))
  })

  output$fs_holidays_preview <- shiny::renderTable({
    df <- combined_holidays()
    if (nrow(df) == 0) return(data.frame(Message = "No holidays configured."))
    df$ds <- format(df$ds, "%Y-%m-%d")
    df
  })

  shiny::observeEvent(input$fs_finalize_holidays, {
    final_holidays(apply_window_settings(combined_holidays(), NULL))
    shiny::showNotification("Holidays finalized.", type = "message")
  })

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

  build_fit_args <- function(model_key, train_df) {
    args <- list(train_df = train_df, date_agg = input$fs_date_agg)
    if (model_key == "prophet") {
      args <- c(args, list(
        holidays_df = final_holidays(), cp = input$fs_cp, season = input$fs_season,
        holiday = input$fs_holiday_prior, exclude_sundays = isTRUE(input$fs_exclude_sundays),
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
    horizon <- convert_months_to_horizon(input$fs_horizon_months, input$fs_date_agg)
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
        date_agg = input$fs_date_agg,
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
    m <- safe_compute_metrics(fm$fc_tib, fm$test, label = get_model(fm$key)$label)
    wide <- tidyr::pivot_wider(m, names_from = "Metric", values_from = "Value")
    DT::datatable(wide, options = list(dom = "t"))
  })

  shiny::observeEvent(input$fs_compare_btn, {
    shiny::req(final_dataset(), input$fs_compare_choices)
    split <- train_test_split()
    horizon <- convert_months_to_horizon(input$fs_horizon_months, input$fs_date_agg)

    results <- lapply(input$fs_compare_choices, function(key) {
      entry <- get_model(key)
      tryCatch({
        model_obj <- do.call(entry$fit, build_fit_args(key, split$train))
        fc_raw <- entry$forecast(model_obj, horizon)
        fc_tib <- entry$to_tibble(fc_raw, split$test)
        safe_compute_metrics(fc_tib, split$test, label = entry$label)
      }, error = function(e) {
        tibble::tibble(Set = entry$label, Metric = c("MASE", "sMAPE (%)", "RMSE"), Value = NA)
      })
    })

    comparison_result(dplyr::bind_rows(results))
    generated_code(build_comparison_code(input$fs_compare_choices, input$fs_date_agg, horizon))
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
