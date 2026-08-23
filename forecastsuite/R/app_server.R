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
  # Grouping: final_dataset() always stays the aggregate ds/y series exactly
  # as before (every existing consumer keeps working unchanged); when a
  # grouping column is set, grouped_series() ALSO holds a named list of
  # per-group ds/y tibbles (R/grouping_utils.R's split_by_group()).
  grouped_series        <- shiny::reactiveVal(NULL)
  grouped_fitted_models <- shiny::reactiveVal(NULL)
  effective_group_col   <- shiny::reactiveVal(NULL)
  grouping_active <- shiny::reactive(!is.null(effective_group_col()))
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
    list(id = "fs_src_paste",  value = "paste",   title = "Paste text"),
    list(id = "fs_src_demo",   value = "demo",    title = "Demo dataset (no data of your own needed)")
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
    shiny::updateSelectInput(session, "fs_group_col", choices = c("(none)" = "", cols), selected = "")
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
    shiny::updateSelectInput(session, "fs_pop_group_col",
                              choices = c("(none) -- apply to the overall series only" = "", names(df)),
                              selected = "")
    shiny::showNotification(sprintf("Loaded population table (%d rows) from %s.", nrow(df), what),
                             type = "message")
    invisible(TRUE)
  }

  # Grouping: fs_group_col picks a column in raw_data(). Real-world
  # grouping columns are often messy ("female"/"Female"/"FEMALE" meant to
  # be one group) -- group_value_map() holds the raw-value -> canonical-
  # label mapping (compute_group_value_map(), R/grouping_utils.R) that
  # drives both the "Merge / relabel values" table and, downstream, which
  # LABEL (not raw value) each row is assigned to at finalize time. The
  # "which to include" checklist always reflects distinct LABELS.
  group_value_map <- shiny::reactiveVal(NULL)

  recompute_group_value_map <- function() {
    shiny::req(raw_data())
    df <- raw_data()
    shiny::req(input$fs_group_col %in% names(df))
    group_value_map(compute_group_value_map(df[[input$fs_group_col]], merge_case = isTRUE(input$fs_group_merge_case)))
  }

  shiny::observeEvent(input$fs_group_col, {
    if (!nzchar(or_default(input$fs_group_col, ""))) {
      group_value_map(NULL)
      shiny::updateCheckboxGroupInput(session, "fs_group_values", choices = character(0))
      return()
    }
    recompute_group_value_map()
  })

  shiny::observeEvent(input$fs_group_merge_case, {
    shiny::req(nzchar(or_default(input$fs_group_col, "")))
    recompute_group_value_map()
  }, ignoreInit = TRUE)

  shiny::observeEvent(input$fs_group_reset_map, {
    shiny::req(nzchar(or_default(input$fs_group_col, "")))
    recompute_group_value_map()
    shiny::showNotification("Value mapping reset.", type = "message")
  })

  shiny::observeEvent(input$fs_group_apply_relabel, {
    sel <- input$fs_group_map_table_rows_selected
    new_label <- trimws(or_default(input$fs_group_new_label, ""))
    shiny::req(length(sel) > 0, nzchar(new_label))
    gmap <- group_value_map()
    shiny::req(gmap)
    gmap$label[sel] <- new_label
    group_value_map(gmap)
    shiny::showNotification(sprintf("Merged %d value(s) into '%s'.", length(sel), new_label), type = "message")
  })

  # The checklist always reflects distinct LABELS, not raw values -- two
  # raw values merged into one label show up as one checkbox. Existing
  # selections are preserved where the label still exists.
  shiny::observeEvent(group_value_map(), {
    gmap <- group_value_map()
    if (is.null(gmap) || nrow(gmap) == 0) {
      shiny::updateCheckboxGroupInput(session, "fs_group_values", choices = character(0))
      return()
    }
    labels <- sort(unique(gmap$label))
    current_sel <- intersect(shiny::isolate(input$fs_group_values), labels)
    selected <- if (length(current_sel)) current_sel else labels
    shiny::updateCheckboxGroupInput(session, "fs_group_values", choices = labels, selected = selected)
  })

  output$fs_group_map_table <- DT::renderDT({
    gmap <- group_value_map()
    shiny::validate(shiny::need(!is.null(gmap) && nrow(gmap) > 0,
                                 "Pick a grouping column to see its distinct values here."))
    shown <- gmap
    names(shown) <- c("Raw value", "Group label")
    DT::datatable(shown, selection = "multiple", rownames = FALSE,
                   options = list(pageLength = 10, scrollX = TRUE))
  })

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

  # Bundled demo dataset (inst/extdata) -- 5 years of simulated daily
  # clinic visits with missing/partially-open Sundays, so someone can
  # explore the whole app (aggregation, recommendation, the Sunday holiday
  # + consistency check) with no data of their own.
  shiny::observeEvent(input$fs_load_demo, {
    path <- system.file("extdata", "forecastsuite_demo_clinic_visits.csv", package = "forecastsuite")
    df <- tryCatch(utils::read.csv(path, check.names = FALSE), error = function(e) NULL)
    accept_imported(df, "the bundled demo dataset")
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

    group_col <- if (nzchar(or_default(input$fs_group_col, ""))) input$fs_group_col else NULL
    pop_group_col <- if (nzchar(or_default(input$fs_pop_group_col, ""))) input$fs_pop_group_col else NULL

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

      if (!is.null(group_col) && !(group_col %in% names(df))) {
        stop("Selected grouping column not found in the uploaded dataset.", call. = FALSE)
      }
      # Merge raw values into their canonical label (the "Merge / relabel
      # values" table) before anything downstream sees this column. Kept
      # as a SEPARATE working column name (pipeline_group_col) rather than
      # overwriting group_col itself: group_col stays the semantic column
      # name the user actually picked (e.g. "District") for
      # effective_group_col() / generated code / the saved project, while
      # every actual data operation below uses whichever column really
      # holds the (possibly merged) labels.
      pipeline_group_col <- group_col
      if (!is.null(group_col)) {
        gmap <- group_value_map()
        if (!is.null(gmap) && nrow(gmap) > 0) {
          label_lookup <- stats::setNames(gmap$label, gmap$raw)
          mapped <- unname(label_lookup[as.character(df[[group_col]])])
          raw_chr <- as.character(df[[group_col]])
          mapped[is.na(mapped)] <- raw_chr[is.na(mapped)]
          df$.fs_group_label <- mapped
          pipeline_group_col <- ".fs_group_label"
        }
      }
      if (!is.null(pipeline_group_col) && length(input$fs_group_values)) {
        df <- df[as.character(df[[pipeline_group_col]]) %in% input$fs_group_values, ]
      }

      use_pop <- isTRUE(input$fs_use_population) && !is.null(pop_data()) &&
        !is.null(input$fs_pop_date_col) && nzchar(input$fs_pop_date_col) &&
        !is.null(input$fs_pop_value_col) && nzchar(input$fs_pop_value_col)

      if (isTRUE(input$fs_use_population) && !use_pop) {
        stop("Population normalization is enabled but the population table or its ",
             "key/value columns are not set.", call. = FALSE)
      }

      # Core pipeline (Stage 1 raw counts -> Stage 2 collapse-by-period ->
      # Stage 3 population incidence), parameterized by which grouping
      # column (if any) THIS run should preserve. Called once with
      # gcol = NULL for the aggregate view -- final_dataset() always stays
      # exactly what the ungrouped path always produced -- and, when
      # grouping is active, once more with gcol = group_col for the
      # per-group view.
      run_pipeline <- function(gcol) {
        if (identical(data_type, "individual")) {
          # One row per event -- process_uploaded_data() already floors
          # each event's date to the period (and group, when gcol is set)
          # and counts, so there is nothing left to collapse.
          collapsed <- process_uploaded_data(
            df, type = "individual", date_col = date_col, date_agg = date_agg,
            group_col = gcol
          )
        } else {
          # Stage 1: raw counts only. Population is deliberately NOT
          # applied here -- normalizing per row and then summing would add
          # rates together. The hosted app splits these stages for the
          # same reason.
          processed <- process_uploaded_data(
            df, type = "agg", date_col = date_col,
            value_col = input$fs_value_col, date_agg = date_agg, group_col = gcol
          )

          # Stage 2: collapse rows sharing a period (e.g. one row per
          # district per quarter) -- without this the series carries
          # repeated ds values. With gcol set, periods collapse WITHIN
          # each group rather than across all of them.
          collapse_fun <- or_default(input$fs_collapse_fun, "sum")
          dupes <- count_duplicate_periods(processed, date_agg, group_col = gcol)
          collapsed <- collapse_to_period(processed, date_agg, fun = collapse_fun, group_col = gcol)
          if (is.null(gcol) && dupes > 0 && !identical(collapse_fun, "none")) {
            shiny::showNotification(
              sprintf("Combined %d rows sharing a period using %s -- %d periods remain.",
                       dupes, collapse_fun, nrow(collapsed)),
              type = "message", duration = 8
            )
          }
        }

        # Stage 3: now that each period (and group) holds one total,
        # convert to incidence.
        if (use_pop) {
          collapsed <- process_uploaded_data(
            as.data.frame(collapsed), type = "agg", date_col = "ds", value_col = "y",
            group_col = gcol,
            date_agg       = date_agg,
            pop_df         = pop_data(),
            pop_date_col   = input$fs_pop_date_col,
            pop_value_col  = input$fs_pop_value_col,
            pop_group_col  = pop_group_col,
            unit_divisor   = or_default(input$fs_unit_scale, 1),
            pop_multiplier = or_default(input$fs_pop_multiplier, 1),
            pop_freq       = input$fs_pop_freq
          )
          if (nrow(collapsed) == 0) {
            stop("Population normalization produced no rows -- the population keys ",
                 "did not match any period in the data. Check the key column ",
                 "(a year like 2021, or a date) against your aggregation.", call. = FALSE)
          }
        }
        collapsed
      }

      aggregate_result <- run_pipeline(NULL)
      grouped_result <- if (!is.null(pipeline_group_col)) run_pipeline(pipeline_group_col) else NULL

      if (use_pop) {
        shiny::showNotification(
          sprintf("Normalized by population: %d periods of incidence.", nrow(aggregate_result)),
          type = "message", duration = 8
        )
      }

      list(data = aggregate_result, grouped = grouped_result,
           group_col = group_col, pipeline_group_col = pipeline_group_col, date_agg = date_agg)
    }, error = function(e) {
      shiny::showNotification(paste("Error:", e$message), type = "error")
      NULL
    })

    if (is.null(result)) {
      final_dataset(NULL)
      grouped_series(NULL)
      effective_group_col(NULL)
    } else {
      effective_date_agg(result$date_agg)
      final_dataset(result$data)
      if (!is.null(result$grouped)) {
        grouped_series(split_by_group(result$grouped, result$pipeline_group_col))
        effective_group_col(result$group_col)
      } else {
        grouped_series(NULL)
        effective_group_col(NULL)
      }
    }
  })

  output$fs_data_preview <- shiny::renderTable({
    shiny::req(final_dataset())
    df <- final_dataset()
    if (nrow(df) == 0) return(data.frame(Message = "No rows to preview."))
    df$ds <- format(df$ds, "%Y-%m-%d")
    utils::head(df, 5)
  })

  output$fs_download_dataset_csv <- shiny::downloadHandler(
    filename = function() paste0("forecastsuite_dataset_", Sys.Date(), ".csv"),
    content = function(file) {
      df <- final_dataset()
      shiny::req(df)
      df$ds <- format(df$ds, "%Y-%m-%d")
      utils::write.csv(df, file, row.names = FALSE)
    }
  )

  output$fs_recommendation <- shiny::renderTable({
    shiny::req(final_dataset())
    df <- final_dataset()
    if (nrow(df) < 4) return(data.frame(Message = "Finalize a dataset with a few more rows to see a recommendation."))
    analysis <- tryCatch(analyze_series(df, effective_date_agg()), error = function(e) NULL)
    if (is.null(analysis)) return(data.frame(Message = "Could not analyze this dataset."))
    holidays_configured <- !is.null(final_holidays()) && nrow(final_holidays()) > 0
    ranked <- recommend_model(analysis, holidays_configured = holidays_configured)
    out <- ranked[, c("model", "key", "score", "reason")]
    out$suggested <- suggest_parameters_for(analysis, ranked$key)
    names(out) <- c("Model", "key", "Overall Score", "Why", "Suggested settings")
    out$`Overall Score` <- round(out$`Overall Score`, 2)

    # When grouping is active, add one more column per included group
    # (the Import tab's checklist) -- same candidates, same order, so a
    # group's column lines up with the Overall row it's next to. Rows stay
    # sorted by Overall Score (recommend_model()'s own ordering); this
    # never rescores or reorders by any group's score.
    gs <- grouped_series()
    if (isTRUE(grouping_active()) && !is.null(gs) && length(gs) > 0) {
      for (g in names(gs)) {
        gdf <- gs[[g]]
        if (is.null(gdf) || nrow(gdf) < 4) next
        g_analysis <- tryCatch(analyze_series(gdf, effective_date_agg()), error = function(e) NULL)
        if (is.null(g_analysis)) next
        g_ranked <- tryCatch(
          recommend_model(g_analysis, holidays_configured = holidays_configured, candidates = out$key),
          error = function(e) NULL
        )
        if (is.null(g_ranked)) next
        scores_by_key <- stats::setNames(round(g_ranked$score, 2), g_ranked$key)
        out[[g]] <- unname(scores_by_key[out$key])
      }
    }

    out$key <- NULL
    out
  })

  # --- Holidays ---
  # The full holiday system (Sundays, fixed catalog, movable-holiday file
  # upload, manual entry, relabel/remove, per-holiday windows and the
  # consistency check) lives in R/app_holidays.R.
  project_restore_holidays <- shiny::reactiveVal(NULL)
  holiday_state <- holidays_server_logic(
    input, output, session,
    final_dataset   = final_dataset,
    read_table_file = read_table_file,
    grouped_series  = grouped_series,
    restore_holidays = project_restore_holidays
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

  # Checklist #2 (distinct from the Import tab's fs_group_values, which
  # decides what enters the finalized dataset at all): which of those
  # included groups actually get fit on a given Fit & Forecast click.
  output$fs_fit_groups_ui <- shiny::renderUI({
    shiny::req(grouping_active())
    groups <- names(grouped_series())
    shiny::checkboxGroupInput("fs_fit_groups", "Groups to fit", choices = groups, selected = groups)
  })

  output$fs_group_view_ui <- shiny::renderUI({
    shiny::req(grouping_active())
    gm <- grouped_fitted_models()
    shiny::validate(shiny::need(length(gm) > 0, "Fit groups (sidebar) to choose one to view here."))
    ok <- names(gm)[!vapply(gm, is.null, logical(1))]
    shiny::validate(shiny::need(length(ok) > 0, "No group fit succeeded."))
    choices <- ok
    # "Reconciled" only makes sense once there's something non-trivial to
    # sum -- with exactly one group fit it would just duplicate that
    # group's own forecast, so it's withheld rather than offered as a
    # confusing no-op.
    if (length(ok) >= 2) choices <- c(choices, "Reconciled (bottom-up)" = ".reconciled")
    shiny::selectInput("fs_group_view", "Viewing group", choices = choices)
  })

  output$fs_holiday_note <- shiny::renderUI({
    shiny::req(input$fs_model_choice)
    entry <- tryCatch(get_model(input$fs_model_choice), error = function(e) NULL)
    if (is.null(entry) || isTRUE(entry$supports_holidays)) return(NULL)
    shiny::div(style = "color:#7a5c00; background-color:#fff3cd; padding:8px; border-radius:4px;",
               holiday_limitation_note(entry$label))
  })

  train_test_split_for <- function(df) {
    test_cutoff <- lubridate::`%m-%`(max(df$ds), months(input$fs_test_months))
    list(train = df[df$ds <= test_cutoff, ], test = df[df$ds > test_cutoff, ])
  }

  # Whichever single series is "in view": the aggregate final_dataset()
  # when ungrouped, or whichever group is picked in fs_group_view when
  # grouping is active. This is the one indirection that lets "Compare
  # Selected Models" (and everything else that only ever calls
  # train_test_split()) keep working completely unchanged while grouping
  # is active -- it always compares against exactly one series, per the
  # confirmed design (grouping never turns Compare into N models x M groups).
  active_series <- function() {
    if (isTRUE(grouping_active())) {
      shiny::req(input$fs_group_view)
      shiny::req(grouped_series())
      grouped_series()[[input$fs_group_view]]
    } else {
      final_dataset()
    }
  }

  train_test_split <- function() train_test_split_for(active_series())

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

  fit_one <- function(model_key, train_df, test_df, horizon) {
    entry <- get_model(model_key)
    model_obj <- do.call(entry$fit, build_fit_args(model_key, train_df))
    fc_raw <- entry$forecast(model_obj, horizon)
    fc_tib <- entry$to_tibble(fc_raw, test_df)
    list(model_obj = model_obj, fc_raw = fc_raw, fc_tib = fc_tib,
         train = train_df, test = test_df, key = model_key)
  }

  shiny::observeEvent(input$fs_fit_btn, {
    shiny::req(final_dataset(), input$fs_model_choice)
    horizon <- convert_months_to_horizon(input$fs_horizon_months, effective_date_agg())
    entry <- get_model(input$fs_model_choice)

    # Fitting is synchronous (blocks the whole app until it returns), and
    # Prophet/TBATS can genuinely take several seconds -- without this the
    # UI just freezes with no feedback, which reads as "did my click even
    # register?" rather than "still working."
    slow_hint <- if (input$fs_model_choice %in% c("prophet", "tbats")) {
      " -- this model can take several seconds"
    } else {
      ""
    }

    if (isTRUE(grouping_active())) {
      shiny::req(grouped_series(), input$fs_fit_groups)
      shiny::showNotification(
        sprintf("Fitting %s across %d group(s)...%s", entry$label, length(input$fs_fit_groups), slow_hint),
        id = "fs_fitting_note", type = "message", duration = NULL
      )
      on.exit(shiny::removeNotification("fs_fitting_note"), add = TRUE)

      runs <- lapply(input$fs_fit_groups, function(g) {
        split <- train_test_split_for(grouped_series()[[g]])
        tryCatch({
          r <- fit_one(input$fs_model_choice, split$train, split$test, horizon)
          r$group <- g
          r
        }, error = function(e) {
          shiny::showNotification(paste0(g, " failed: ", conditionMessage(e)), type = "warning")
          NULL
        })
      })
      names(runs) <- input$fs_fit_groups
      grouped_fitted_models(runs)
      fitted_model(NULL)

      ok <- names(runs)[!vapply(runs, is.null, logical(1))]
      if (length(ok)) {
        generated_code(build_fit_code_grouped(
          model_key = input$fs_model_choice, date_agg = effective_date_agg(),
          scalar_args = scalar_fit_args_for_code(input$fs_model_choice),
          uses_holidays = identical(input$fs_model_choice, "prophet"),
          horizon = horizon, group_col = effective_group_col(), groups = ok
        ))
      }
    } else {
      shiny::showNotification(paste0("Fitting ", entry$label, "...", slow_hint),
                               id = "fs_fitting_note", type = "message", duration = NULL)
      on.exit(shiny::removeNotification("fs_fitting_note"), add = TRUE)

      split <- train_test_split()
      result <- tryCatch(
        fit_one(input$fs_model_choice, split$train, split$test, horizon),
        error = function(e) {
          shiny::showNotification(paste("Fit failed:", e$message), type = "error")
          NULL
        }
      )
      fitted_model(result)
      grouped_fitted_models(NULL)

      if (!is.null(result)) {
        generated_code(build_fit_code(
          model_key = input$fs_model_choice,
          date_agg = effective_date_agg(),
          scalar_args = scalar_fit_args_for_code(input$fs_model_choice),
          uses_holidays = identical(input$fs_model_choice, "prophet"),
          horizon = horizon
        ))
      }
    }
  })

  # Bottom-up hierarchical reconciliation: the aggregate forecast becomes
  # the sum of the already-fit group forecasts (see R/reconciliation.R for
  # why this needs no extra model fit and is always coherent). Builds a
  # fitted_model()-shaped synthetic list so every existing single-series
  # render/download/metrics output "just works" on it via active_fit(),
  # with no changes of their own needed.
  reconciled_fit <- shiny::reactive({
    shiny::req(isTRUE(grouping_active()), grouped_fitted_models())
    gm <- grouped_fitted_models()
    ok <- gm[!vapply(gm, is.null, logical(1))]
    shiny::req(length(ok) >= 2)
    rec <- reconcile_bottom_up(ok)
    list(
      model_obj = NULL,
      fc_raw = rec$fc_tib, fc_tib = rec$fc_tib,
      train = rec$train, test = rec$test,
      key = ok[[1]]$key,
      group = ".reconciled",
      reconciled = TRUE,
      components = rec$components,
      partial = length(rec$components) < length(grouped_series())
    )
  })

  # Whichever single fit result is "in view" -- mirrors active_series():
  # the last single-model fit when ungrouped, or the currently-picked
  # group's fit (or the reconciled bottom-up sum) when grouping is active.
  # current_forecast_plot_args() and fs_metrics_table read this instead of
  # fitted_model() directly so they don't need to know which mode is active.
  active_fit <- shiny::reactive({
    if (isTRUE(grouping_active())) {
      shiny::req(input$fs_group_view)
      if (identical(input$fs_group_view, ".reconciled")) return(reconciled_fit())
      shiny::req(grouped_fitted_models())
      grouped_fitted_models()[[input$fs_group_view]]
    } else {
      fitted_model()
    }
  })

  # Shared by the plotly render and the PNG download so the two always
  # match exactly what's on screen -- appearance toggles/colors included.
  current_forecast_plot_args <- function() {
    shiny::req(active_fit())
    fm <- active_fit()
    entry <- get_model(fm$key)
    subtitle <- if (isTRUE(fm$reconciled)) {
      partial_note <- if (isTRUE(fm$partial)) {
        sprintf(" -- partial: %d of %d configured groups", length(fm$components), length(grouped_series()))
      } else {
        ""
      }
      sprintf("Bottom-up sum of %d group(s): %s%s",
              length(fm$components), paste(fm$components, collapse = ", "), partial_note)
    } else if (!is.null(entry$annotate)) {
      entry$annotate(fm$model_obj)
    } else {
      NULL
    }
    # Only Prophet's raw forecast() output is a data.frame with the richer
    # trend/holidays columns plot_forecast_generic() can use; the
    # forecast-package models (ARIMA/SARIMA/ETS/TBATS/NNETAR/Holt-Winters)
    # return a `forecast`-class S3 object instead, so fall back to the
    # already-standardized ds/yhat tibble for those.
    plot_input <- if (is.data.frame(fm$fc_raw)) fm$fc_raw else fm$fc_tib
    list(
      forecast_df = plot_input, train_df = fm$train, model_obj = fm$model_obj,
      subtitle = subtitle,
      show_trend = isTRUE(input$fs_show_trend),
      show_uncertainty = isTRUE(input$fs_show_uncertainty),
      show_holidays = isTRUE(input$fs_show_holidays) && isTRUE(entry$supports_holidays),
      show_changepoints = isTRUE(input$fs_show_changepoints),
      color_actual = or_default(input$fs_color_actual, "#1b9e77"),
      color_forecast = or_default(input$fs_color_forecast, "#d95f02"),
      color_trend = or_default(input$fs_color_trend, "#7570b3"),
      color_ci = or_default(input$fs_color_ci, "#1b9e77")
    )
  }

  output$fs_forecast_plot <- plotly::renderPlotly({
    do.call(plot_forecast_generic, current_forecast_plot_args())
  })

  output$fs_download_forecast_png <- shiny::downloadHandler(
    filename = function() paste0("forecastsuite_forecast_", Sys.Date(), ".png"),
    content = function(file) {
      do.call(render_forecast_png, c(list(file = file), current_forecast_plot_args()))
    }
  )

  output$fs_metrics_table <- DT::renderDT({
    shiny::validate(shiny::need(active_fit(), "Fit a model to see results here."))
    fm <- active_fit()
    m <- compute_multi_window_metrics(fm$fc_tib, fm$train, fm$test, effective_date_agg())
    shiny::validate(shiny::need(nrow(m) > 0, "Not enough data to score this forecast."))
    wide <- tidyr::pivot_wider(m, names_from = "Metric", values_from = "Value")
    DT::datatable(wide, options = list(dom = "t", scrollX = TRUE), rownames = FALSE)
  })

  # --- Rolling-origin cross-validation ---
  # A separate, explicit action from Fit & Forecast (like Compare Selected
  # Models) since it refits the model K times -- much more expensive,
  # especially for Prophet/TBATS. Scoped to whichever single series is
  # currently in view via active_series(), the same scope rule Compare
  # Selected Models already uses -- never multiplies across groups.
  cv_result <- shiny::reactiveVal(NULL)

  shiny::observeEvent(input$fs_run_cv, {
    shiny::req(active_series(), input$fs_model_choice)
    entry <- get_model(input$fs_model_choice)
    horizon_periods <- convert_months_to_horizon(input$fs_test_months, effective_date_agg())
    k_requested <- or_default(input$fs_cv_folds, 3)

    folds <- build_cv_folds(active_series(), horizon_periods, k_requested)
    if (length(folds) == 0) {
      shiny::showNotification(
        "Not enough data for even one cross-validation fold at this test-window length.",
        type = "error"
      )
      return()
    }
    if (length(folds) < k_requested) {
      shiny::showNotification(
        sprintf("Only %d of %d requested folds fit in this series -- using %d.",
                 length(folds), k_requested, length(folds)),
        type = "warning", duration = 8
      )
    }

    slow_hint <- if (input$fs_model_choice %in% c("prophet", "tbats")) {
      sprintf(" (~2-5s per fold, %d fold(s) total)", length(folds))
    } else {
      sprintf(" (%d fold(s))", length(folds))
    }
    shiny::showNotification(
      sprintf("Running %d-fold cross-validation for %s%s...", length(folds), entry$label, slow_hint),
      id = "fs_cv_note", type = "message", duration = NULL
    )
    on.exit(shiny::removeNotification("fs_cv_note"), add = TRUE)

    fold_metrics <- lapply(seq_along(folds), function(i) {
      f <- folds[[i]]
      tryCatch({
        r <- fit_one(input$fs_model_choice, f$train, f$test, horizon_periods)
        safe_compute_metrics(r$fc_tib, f$test, label = paste0("Fold ", i))
      }, error = function(e) {
        shiny::showNotification(paste0("Fold ", i, " failed: ", conditionMessage(e)), type = "warning")
        tibble::tibble(Set = paste0("Fold ", i), Metric = c("MASE", "sMAPE (%)", "RMSE"), Value = NA_real_)
      })
    })
    long <- dplyr::bind_rows(fold_metrics)

    summary_wide <- long |>
      dplyr::group_by(Metric) |>
      dplyr::summarise(Mean = mean(Value, na.rm = TRUE), SD = stats::sd(Value, na.rm = TRUE), .groups = "drop")
    summary_long <- dplyr::bind_rows(
      tibble::tibble(Set = "Mean", Metric = summary_wide$Metric, Value = summary_wide$Mean),
      tibble::tibble(Set = "SD",   Metric = summary_wide$Metric, Value = summary_wide$SD)
    )

    cv_result(dplyr::bind_rows(long, summary_long))
  })

  output$fs_cv_table <- DT::renderDT({
    shiny::validate(shiny::need(cv_result(), "Click Run Cross-Validation to see fold-by-fold results here."))
    wide <- tidyr::pivot_wider(cv_result(), names_from = "Metric", values_from = "Value")
    DT::datatable(wide, options = list(dom = "t", scrollX = TRUE), rownames = FALSE)
  })

  # Called directly (not via reconciled_fit(), which shiny::req()s out
  # entirely below 2 fitted groups) so the overlay plot only loses its
  # extra trace rather than blanking completely when just one group is fit.
  .fs_overlay_series <- function(gm) {
    fcs <- lapply(gm, `[[`, "fc_tib")
    actuals <- lapply(gm, `[[`, "train")
    if (length(gm) >= 2) {
      rec <- reconcile_bottom_up(gm)
      fcs[["Reconciled (bottom-up)"]] <- rec$fc_tib
      actuals[["Reconciled (bottom-up)"]] <- rec$train
    }
    list(fcs = fcs, actuals = actuals)
  }

  output$fs_group_overlay_plot <- plotly::renderPlotly({
    shiny::validate(shiny::need(isTRUE(grouping_active()) && length(grouped_fitted_models()) > 0,
                                 "Fit groups (sidebar) to compare their forecasts here."))
    gm <- grouped_fitted_models()
    gm <- gm[!vapply(gm, is.null, logical(1))]
    shiny::validate(shiny::need(length(gm) > 0, "No group fit succeeded."))
    series <- .fs_overlay_series(gm)
    plot_group_overlay(series$fcs, series$actuals)
  })

  output$fs_download_group_overlay_png <- shiny::downloadHandler(
    filename = function() paste0("forecastsuite_group_overlay_", Sys.Date(), ".png"),
    content = function(file) {
      gm <- grouped_fitted_models()
      shiny::req(gm)
      gm <- gm[!vapply(gm, is.null, logical(1))]
      shiny::req(length(gm) > 0)
      series <- .fs_overlay_series(gm)
      render_group_overlay_png(file, series$fcs, series$actuals)
    }
  )

  shiny::observeEvent(input$fs_compare_btn, {
    shiny::req(final_dataset(), input$fs_compare_choices)
    split <- train_test_split()
    horizon <- convert_months_to_horizon(input$fs_horizon_months, effective_date_agg())

    slow_selected <- intersect(input$fs_compare_choices, c("prophet", "tbats"))
    slow_hint <- if (length(slow_selected)) " -- Prophet/TBATS can each take several seconds" else ""
    shiny::showNotification(
      paste0("Fitting ", length(input$fs_compare_choices), " model(s)...", slow_hint),
      id = "fs_fitting_note", type = "message", duration = NULL
    )
    on.exit(shiny::removeNotification("fs_fitting_note"), add = TRUE)

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

  output$fs_download_comparison_png <- shiny::downloadHandler(
    filename = function() paste0("forecastsuite_comparison_", Sys.Date(), ".png"),
    content = function(file) {
      fcs <- comparison_forecasts()
      shiny::req(fcs)
      fcs <- fcs[!vapply(fcs, is.null, logical(1))]
      shiny::req(length(fcs) > 0)
      render_comparison_png(file, fcs, train_df = comparison_train())
    }
  )

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

  # --- Project save/load (R/project_io.R) ---
  # Setup only -- never fitted model objects (see project_io.R's header
  # for why: Prophet's Stan-backed objects aren't guaranteed to survive a
  # saveRDS()/readRDS() round-trip into a fresh R session). Loading
  # bypasses re-import entirely: final_dataset()/grouped_series() are
  # restored directly, so the Import tab's own column pickers simply
  # won't reflect anything afterward -- there's nothing to re-derive them
  # from without the original raw file, which the notification below
  # states explicitly.
  output$fs_download_project <- shiny::downloadHandler(
    filename = function() paste0("forecastsuite_project_", Sys.Date(), ".rds"),
    content = function(file) {
      shiny::req(final_dataset())
      payload <- build_project_payload(
        final_dataset = final_dataset(), grouped_series = grouped_series(),
        effective_group_col = effective_group_col(), effective_date_agg = effective_date_agg(),
        holidays_compiled = combined_holidays(), holidays_windows = holiday_state$windows(),
        holidays_final = final_holidays(),
        ui_inputs = list(
          fs_model_choice = input$fs_model_choice, fs_horizon_months = input$fs_horizon_months,
          fs_test_months = input$fs_test_months, fs_cp = input$fs_cp, fs_season = input$fs_season,
          fs_holiday_prior = input$fs_holiday_prior, fs_yearly = input$fs_yearly,
          fs_weekly = input$fs_weekly, fs_daily = input$fs_daily,
          fs_exclude_sundays = input$fs_exclude_sundays, fs_arima_mode = input$fs_arima_mode,
          fs_p = input$fs_p, fs_d = input$fs_d, fs_q = input$fs_q,
          fs_P = input$fs_P, fs_D = input$fs_D, fs_Q = input$fs_Q,
          fs_show_trend = input$fs_show_trend, fs_show_uncertainty = input$fs_show_uncertainty,
          fs_show_holidays = input$fs_show_holidays, fs_show_changepoints = input$fs_show_changepoints,
          fs_color_actual = input$fs_color_actual, fs_color_forecast = input$fs_color_forecast,
          fs_color_trend = input$fs_color_trend, fs_color_ci = input$fs_color_ci,
          fs_compare_choices = input$fs_compare_choices, fs_cv_folds = input$fs_cv_folds,
          fs_holiday_years = input$fs_holiday_years, fs_use_holidays = input$fs_use_holidays
        )
      )
      saveRDS(payload, file)
    }
  )

  shiny::observeEvent(input$fs_project_file, {
    shiny::req(input$fs_project_file)
    payload <- tryCatch(readRDS(input$fs_project_file$datapath), error = function(e) NULL)
    if (is.null(payload) || is.null(payload$schema_version)) {
      shiny::showNotification("Could not read that file as a forecastsuite project.", type = "error")
      return()
    }

    final_dataset(payload$final_dataset)
    grouped_series(payload$grouped_series)
    effective_group_col(payload$effective_group_col)
    effective_date_agg(payload$effective_date_agg)
    fitted_model(NULL)
    grouped_fitted_models(NULL)

    if (!is.null(payload$grouped_series)) {
      gnames <- names(payload$grouped_series)
      shiny::updateCheckboxGroupInput(session, "fs_group_values", choices = gnames, selected = gnames)
    }

    project_restore_holidays(list(
      compiled = payload$holidays_compiled,
      windows  = payload$holidays_windows,
      final    = payload$holidays_final
    ))
    # The final_dataset() set above fires holidays_server_logic()'s own
    # year-default observer, which would otherwise clobber this restore --
    # both are plain sequential observeEvents in the same flush cycle, so
    # this ordering (project_restore_holidays() called here, after
    # final_dataset()) is what makes the explicit fs_holiday_years/
    # fs_use_holidays restore below win instead of being overwritten.
    if (!is.null(payload$ui_inputs$fs_holiday_years)) {
      shiny::updateSliderInput(session, "fs_holiday_years", value = payload$ui_inputs$fs_holiday_years)
    }
    if (!is.null(payload$ui_inputs$fs_use_holidays)) {
      shiny::updateCheckboxInput(session, "fs_use_holidays", value = payload$ui_inputs$fs_use_holidays)
    }
    restore_project_inputs(session, payload)

    shiny::showNotification(
      "Project loaded -- click Fit & Forecast (and Run Cross-Validation / group fitting) to continue.",
      type = "message", duration = 8
    )
  })
}
