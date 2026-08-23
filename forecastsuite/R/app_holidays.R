# Full holiday system, ported from the hosted app's Holidays tab
# (ui/ui_tab2_holidays.R + server/server_holidays.R). Everything here
# drives the helpers already in R/holidays_helpers.R, which were copied
# across earlier but left unused by the first version of this app.
#
# Sources that feed one compiled list:
#   - Sundays over a year range
#   - a fixed-date catalog (Republic Day, Christmas, ...)
#   - movable holidays uploaded as a file, with column mapping
#   - manual entries, either repeating every year or one-off
# The compiled list can then be edited (relabel / remove), given per-
# holiday lower/upper windows, checked against the data for consistency,
# and finalized for Prophet.

# Month-day -> label. Matches the hosted app's catalog exactly.
fixed_holiday_catalog <- function() {
  c(
    "01-26" = "Republic Day",
    "08-15" = "Independence Day",
    "10-02" = "Gandhi Jayanti",
    "12-25" = "Christmas",
    "04-14" = "Ambedkar Jayanti",
    "01-14" = "Makar Sankranti"
  )
}

build_holidays_tab_ui <- function() {
  catalog <- fixed_holiday_catalog()
  catalog_choices <- stats::setNames(names(catalog), paste0(catalog, " (", names(catalog), ")"))

  shiny::sidebarLayout(
    shiny::sidebarPanel(
      width = 4,
      shiny::checkboxInput("fs_use_holidays", "Enable holiday effects", TRUE),

      shiny::conditionalPanel(
        condition = "input.fs_use_holidays == true",

        shiny::tags$details(
          open = TRUE,
          shiny::tags$summary("Sundays and fixed-date holidays"),
          shiny::sliderInput("fs_holiday_years", "Year range",
                              min = 2000, max = 2040,
                              value = c(2018, 2030), sep = ""),
          shiny::checkboxInput("fs_include_sundays", "Include Sundays", TRUE),
          shiny::checkboxGroupInput("fs_fixed_holidays", "Fixed holidays",
                                     choices = catalog_choices),
          shiny::actionButton("fs_generate_fixed", "Generate", class = "btn-primary", width = "100%")
        ),

        shiny::tags$details(
          open = FALSE,
          shiny::tags$summary("Movable holidays from a file"),
          shiny::p(style = "font-size:12px;color:#777;",
                   "For holidays whose date shifts each year (Eid, Diwali, Easter). Upload a table with a date column and a label column."),
          shiny::fileInput("fs_movable_file", "Holiday table (CSV / Excel)",
                            accept = c(".csv", ".tsv", ".txt", ".xlsx", ".xls")),
          shiny::selectInput("fs_movable_date_col", "Date column", choices = NULL),
          shiny::selectInput("fs_movable_label_col", "Label column", choices = NULL),
          shiny::actionButton("fs_add_movable", "Add movable holidays", class = "btn-primary", width = "100%")
        ),

        shiny::tags$details(
          open = FALSE,
          shiny::tags$summary("Add one manually"),
          shiny::radioButtons("fs_manual_type", "Type",
                               choices = c("Repeats every year" = "fixed",
                                            "This date only" = "movable"),
                               selected = "fixed"),
          shiny::dateInput("fs_manual_date", "Date"),
          shiny::textInput("fs_manual_label", "Label"),
          shiny::actionButton("fs_add_manual", "Add", class = "btn-primary", width = "100%")
        ),

        shiny::tags$details(
          open = FALSE,
          shiny::tags$summary("Holiday windows"),
          shiny::p(style = "font-size:12px;color:#777;",
                   "Days before/after a holiday that share its effect, e.g. a long weekend."),
          shiny::selectInput("fs_window_label", "Holiday", choices = NULL),
          shiny::numericInput("fs_lower_window", "Days before", value = 0, min = 0),
          shiny::numericInput("fs_upper_window", "Days after", value = 0, min = 0),
          shiny::actionButton("fs_apply_window", "Apply window", width = "100%"),
          shiny::tableOutput("fs_window_table")
        ),

        shiny::hr(),
        shiny::actionButton("fs_finalize_holidays", "Finalize Holidays",
                             class = "btn-success", width = "100%")
      )
    ),

    shiny::mainPanel(
      width = 8,
      shiny::h4("Compiled holidays"),
      shiny::verbatimTextOutput("fs_holiday_summary"),
      shinycssloaders::withSpinner(DT::DTOutput("fs_holiday_table"), type = 6),
      shiny::downloadButton("fs_download_holidays_csv", "Download Holidays (CSV)"),
      shiny::fluidRow(
        shiny::column(5, shiny::textInput("fs_new_label", "Relabel selected row", "")),
        shiny::column(3, shiny::br(),
                       shiny::actionButton("fs_apply_edit", "Apply label", width = "100%")),
        shiny::column(4, shiny::br(),
                       shiny::actionButton("fs_remove_selected", "Remove selected", class = "btn-warning", width = "100%"),
                       shiny::tags$br(),
                       shiny::tags$div(style = "margin-top:6px;"),
                       shiny::actionButton("fs_clear_holidays", "Clear all", class = "btn-danger", width = "100%"))
      ),

      shiny::hr(),
      shiny::h4("Consistency check"),
      shiny::p(style = "font-size:12px;color:#777;",
               "Cross-checks declared holidays against the data: days marked as holidays that still carry values, and calendar dates that are zero or missing every year but were never declared."),
      shiny::checkboxInput("fs_enable_contingency", "Run consistency check", FALSE),
      shiny::conditionalPanel(
        condition = "input.fs_enable_contingency == true",
        shiny::uiOutput("fs_contingency_scope_ui"),
        shiny::h5("Holidays with non-zero data"),
        shinycssloaders::withSpinner(DT::DTOutput("fs_holidays_with_data"), type = 6),
        shiny::h5("Dates always zero or missing"),
        shinycssloaders::withSpinner(DT::DTOutput("fs_always_zero"), type = 6)
      )
    )
  )
}

# Wires the holiday tab. `final_dataset` is the reactive holding the
# finalized ds/y series (used for year defaults and the consistency
# check). Returns the reactives the rest of the app needs.
holidays_server_logic <- function(input, output, session, final_dataset,
                                   read_table_file,
                                   grouped_series = shiny::reactive(NULL),
                                   restore_holidays = shiny::reactiveVal(NULL)) {
  compiled  <- shiny::reactiveVal(tibble::tibble(ds = as.Date(character()), holiday = character()))
  windows   <- shiny::reactiveVal(tibble::tibble(holiday = character(),
                                                  lower_window = integer(),
                                                  upper_window = integer()))
  finalized <- shiny::reactiveVal(NULL)
  movable_raw <- shiny::reactiveVal(NULL)

  # Project load (R/project_io.R): pushes a saved holiday state back into
  # the three private reactiveVals above directly, so the caller
  # (build_app_server) never needs its own setters for them.
  shiny::observeEvent(restore_holidays(), {
    payload <- restore_holidays()
    shiny::req(payload)
    if (!is.null(payload$compiled)) compiled(payload$compiled)
    if (!is.null(payload$windows)) windows(payload$windows)
    if (!is.null(payload$final)) finalized(payload$final)
  })

  add_holidays <- function(new_df, what) {
    if (is.null(new_df) || nrow(new_df) == 0) {
      shiny::showNotification(paste0("No holidays added from ", what, "."), type = "warning")
      return(invisible(FALSE))
    }
    merged <- dplyr::distinct(dplyr::bind_rows(compiled(), new_df[, c("ds", "holiday")]))
    merged <- merged[order(merged$ds), ]
    compiled(merged)
    shiny::showNotification(sprintf("Added %d holiday dates from %s.", nrow(new_df), what),
                             type = "message")
    invisible(TRUE)
  }

  # Default the year slider to the span of the loaded data.
  shiny::observeEvent(final_dataset(), {
    df <- final_dataset()
    shiny::req(df, nrow(df) > 0)
    yrs <- range(lubridate::year(df$ds), na.rm = TRUE)
    shiny::updateSliderInput(session, "fs_holiday_years",
                              value = c(yrs[1], yrs[2] + 5))
  })

  # --- Sundays + fixed catalog ---
  shiny::observeEvent(input$fs_generate_fixed, {
    yrs <- input$fs_holiday_years
    shiny::req(yrs)
    parts <- list()

    if (isTRUE(input$fs_include_sundays)) {
      parts <- c(parts, list(generate_sundays(yrs[1], yrs[2])))
    }
    if (length(input$fs_fixed_holidays)) {
      parts <- c(parts, list(expand_fixed_holidays(
        selected  = input$fs_fixed_holidays,
        years     = seq(yrs[1], yrs[2]),
        label_map = as.list(fixed_holiday_catalog())
      )))
    }
    if (!length(parts)) {
      shiny::showNotification("Tick Sundays and/or at least one fixed holiday first.",
                               type = "warning")
      return()
    }
    add_holidays(dplyr::bind_rows(parts), "Sundays / fixed holidays")
  })

  # --- Movable holidays from a file ---
  shiny::observeEvent(input$fs_movable_file, {
    shiny::req(input$fs_movable_file)
    df <- read_table_file(input$fs_movable_file$datapath, input$fs_movable_file$name)
    if (is.null(df)) {
      shiny::showNotification("Could not read that holiday file.", type = "error")
      return()
    }
    movable_raw(df)
    shiny::updateSelectInput(session, "fs_movable_date_col", choices = names(df))
    shiny::updateSelectInput(session, "fs_movable_label_col", choices = names(df))
  })

  shiny::observeEvent(input$fs_add_movable, {
    shiny::req(movable_raw(), input$fs_movable_date_col, input$fs_movable_label_col)
    parsed <- tryCatch(
      parse_movable_holidays(movable_raw(), input$fs_movable_date_col, input$fs_movable_label_col),
      error = function(e) {
        shiny::showNotification(paste("Could not parse holidays:", conditionMessage(e)),
                                 type = "error")
        NULL
      }
    )
    if (!is.null(parsed)) add_holidays(parsed, "the uploaded file")
  })

  # --- Manual entry ---
  shiny::observeEvent(input$fs_add_manual, {
    shiny::req(input$fs_manual_date, nzchar(trimws(input$fs_manual_label)))
    yrs <- input$fs_holiday_years
    years <- if (is.null(yrs)) lubridate::year(input$fs_manual_date) else seq(yrs[1], yrs[2])
    entry <- apply_manual_entry(NULL, input$fs_manual_date, input$fs_manual_label,
                                 input$fs_manual_type, years)
    add_holidays(entry, "manual entry")
    shiny::updateTextInput(session, "fs_manual_label", value = "")
  })

  # --- Compiled list: display, relabel, remove ---
  output$fs_holiday_summary <- shiny::renderPrint({
    df <- compiled()
    if (nrow(df) == 0) {
      cat("No holidays configured yet.\n")
    } else {
      cat(sprintf("%d dates across %d distinct labels, %s to %s.\n",
                   nrow(df), length(unique(df$holiday)),
                   format(min(df$ds)), format(max(df$ds))))
      print(sort(table(df$holiday), decreasing = TRUE))
    }
  })

  output$fs_holiday_table <- DT::renderDT({
    df <- compiled()
    shiny::validate(shiny::need(nrow(df) > 0, "No holidays configured yet."))
    shown <- df
    shown$ds <- format(shown$ds, "%Y-%m-%d")
    DT::datatable(shown, selection = "multiple", rownames = FALSE,
                   options = list(pageLength = 10, scrollX = TRUE))
  })

  shiny::observeEvent(input$fs_apply_edit, {
    sel <- input$fs_holiday_table_rows_selected
    shiny::req(length(sel) > 0, nzchar(trimws(input$fs_new_label)))
    compiled(apply_label_edit(compiled(), sel, input$fs_new_label))
    shiny::showNotification(sprintf("Relabelled %d row(s).", length(sel)), type = "message")
  })

  shiny::observeEvent(input$fs_remove_selected, {
    sel <- input$fs_holiday_table_rows_selected
    shiny::req(length(sel) > 0)
    compiled(compiled()[-sel, , drop = FALSE])
    shiny::showNotification(sprintf("Removed %d row(s).", length(sel)), type = "message")
  })

  shiny::observeEvent(input$fs_clear_holidays, {
    compiled(tibble::tibble(ds = as.Date(character()), holiday = character()))
    windows(tibble::tibble(holiday = character(), lower_window = integer(), upper_window = integer()))
    finalized(NULL)
  })

  # --- Per-holiday windows ---
  shiny::observe({
    labels <- sort(unique(compiled()$holiday))
    shiny::updateSelectInput(session, "fs_window_label",
                              choices = if (length(labels)) labels else character(0))
  })

  shiny::observeEvent(input$fs_apply_window, {
    shiny::req(input$fs_window_label)
    current <- windows()
    current <- current[current$holiday != input$fs_window_label, , drop = FALSE]
    windows(dplyr::bind_rows(current, tibble::tibble(
      holiday      = input$fs_window_label,
      lower_window = as.integer(or_zero(input$fs_lower_window)),
      upper_window = as.integer(or_zero(input$fs_upper_window))
    )))
    shiny::showNotification(paste0("Window set for ", input$fs_window_label, "."), type = "message")
  })

  output$fs_window_table <- shiny::renderTable({
    df <- windows()
    if (nrow(df) == 0) return(data.frame(Message = "No windows set (all default to 0)."))
    df
  })

  # --- Finalize ---
  shiny::observeEvent(input$fs_finalize_holidays, {
    if (!isTRUE(input$fs_use_holidays)) {
      finalized(NULL)
      shiny::showNotification("Holiday effects disabled -- models will run without holidays.",
                               type = "message")
      return()
    }
    df <- compiled()
    if (nrow(df) == 0) {
      finalized(NULL)
      shiny::showNotification("No holidays to finalize.", type = "warning")
      return()
    }
    finalized(apply_window_settings(df, windows()))
    shiny::showNotification(sprintf("Finalized %d holiday dates.", nrow(df)), type = "message")
  })

  # --- Consistency check ---
  # When grouping is active, "Combined (all groups)" (the default) checks
  # against the exact same aggregate final_dataset() the ungrouped path
  # always used; picking one group instead checks that group's own data,
  # since a date that's zero for every year in the aggregate can still
  # hide a real, group-specific pattern (e.g. genuinely closed on
  # Sundays for District A but not District B).
  output$fs_contingency_scope_ui <- shiny::renderUI({
    gs <- grouped_series()
    shiny::req(gs, length(gs) > 0)
    shiny::selectInput("fs_contingency_scope", "Check against",
                        choices = c("Combined (all groups)" = ".combined", names(gs)))
  })

  contingency_data <- shiny::reactive({
    gs <- grouped_series()
    scope <- input$fs_contingency_scope
    if (!is.null(gs) && length(gs) > 0 && !is.null(scope) && !identical(scope, ".combined")) {
      gs[[scope]]
    } else {
      final_dataset()
    }
  })

  contingency <- shiny::reactive({
    shiny::req(isTRUE(input$fs_enable_contingency), contingency_data())
    holiday_contingency(compiled(), contingency_data())
  })

  output$fs_holidays_with_data <- DT::renderDT({
    res <- contingency()$with_data
    shiny::validate(shiny::need(nrow(res) > 0,
      "No declared holiday carries a non-zero value -- nothing inconsistent here."))
    res$ds <- format(res$ds, "%Y-%m-%d")
    DT::datatable(res, options = list(pageLength = 5, scrollX = TRUE), rownames = FALSE)
  })

  output$fs_always_zero <- DT::renderDT({
    res <- contingency()$always_zero
    shiny::validate(shiny::need(nrow(res) > 0,
      "No calendar date is zero or missing in every year."))
    res$ds <- format(res$ds, "%Y-%m-%d")
    names(res)[names(res) == "declared_holiday"] <- "Already declared"
    DT::datatable(res, options = list(pageLength = 5, scrollX = TRUE), rownames = FALSE)
  })

  output$fs_download_holidays_csv <- shiny::downloadHandler(
    filename = function() paste0("forecastsuite_holidays_", Sys.Date(), ".csv"),
    content = function(file) {
      df <- compiled()
      if (is.null(df) || nrow(df) == 0) {
        df <- tibble::tibble(ds = as.Date(character()), holiday = character())
      }
      utils::write.csv(df, file, row.names = FALSE)
    }
  )

  list(compiled = compiled, windows = windows, final = finalized)
}

or_zero <- function(x) if (is.null(x) || length(x) != 1 || is.na(x)) 0L else x
