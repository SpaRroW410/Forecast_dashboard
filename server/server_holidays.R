source("helpers/holidays_helpers.R", local = TRUE)

holidays_server <- function(input, output, session, dataset) {
  # Empty-table constructors: working state is reset to these (never NULL), so
  # every observer below can rely on getting a data frame back.
  empty_holidays <- function() tibble(ds = as.Date(character()), holiday = character())
  empty_windows  <- function() tibble(holiday = character(), lower_window = integer(), upper_window = integer())

  movable_holidays    <- import_panel_server("hol")
  manual_fixed        <- reactiveVal(empty_holidays())
  manual_movable      <- reactiveVal(empty_holidays())
  compiled_holidays   <- reactiveVal(empty_holidays())
  holiday_windows     <- reactiveVal(empty_windows())
  # NULL until the user finalizes a non-empty holiday list; the forecast tab
  # treats NULL as "forecast without holidays".
  final_holidays      <- reactiveVal(NULL)
  
  # 🗂 Column mapping (restored)
  output$movable_date_col <- renderUI({
    req(movable_holidays())
    selectInput("date_col", "Date column:", choices = names(movable_holidays()))
  })
  
  output$movable_label_col <- renderUI({
    req(movable_holidays())
    # Default to the second column: the example file (and most holiday lists)
    # put the date first and the name second, and defaulting both pickers to
    # the first column silently named every imported holiday after its date.
    cols <- names(movable_holidays())
    selectInput("label_col", "Holiday name column:", choices = cols,
                selected = if (length(cols) >= 2) cols[2] else cols[1])
  })
  
  # ➕ Add imported (movable) holidays to the working list
  observeEvent(input$finalize_movable, {
    if (!notify_unless(!is.null(movable_holidays()),
                       "Import a holiday file first: click \"Add holidays from a file…\" and then \"Import data\".")) return()
    req(input$date_col, input$label_col)
    showNotification("⏳ Adding imported holidays...", type = "default", duration = 2)

    # A date column that isn't dates makes as.Date() throw, which used to end
    # the session; explain instead. Zero parsed rows gets its own message.
    df <- try_notify(parse_movable_holidays(movable_holidays(), input$date_col, input$label_col),
                     sprintf("The column \"%s\" could not be read as dates (expected e.g. 2024-01-26). Choose the date column", input$date_col),
                     session = session)
    if (is.null(df)) return()
    if (!notify_unless(nrow(df) > 0, sprintf("No valid dates were found in the column \"%s\" (expected e.g. 2024-01-26).", input$date_col))) return()
    compiled_holidays(bind_rows(compiled_holidays(), df) %>% distinct())

    showModal(modalDialog(
      title = "✅ Imported holidays added",
      sprintf("%d holiday dates from your file were added to the working holiday list. Review it on step 4.", nrow(df)),
      easyClose = TRUE,
      footer = modalButton("OK")
    ))
  })
  
  # 🧮 Build the working list from Sundays + fixed holidays + manual entries
  observeEvent(input$compile_fixed_holidays, {
    showNotification("⏳ Building the holiday list...", type = "default", duration = 2)
    req(input$use_holiday_effects == "yes", dataset())
    
    ds_col <- dataset()$ds
    req(length(ds_col) > 0, any(!is.na(ds_col)))
    
    dfs <- list()
    
    if (isTRUE(input$include_sundays)) {
      start_year <- input$holiday_years[1]
      end_year   <- input$holiday_years[2]
      dfs <- append(dfs, list(generate_sundays(start_year, end_year)))
    }
    
    if (!is.null(input$fixed_holidays) && length(input$fixed_holidays) > 0) {
      years <- seq(input$holiday_years[1], input$holiday_years[2])
      label_map <- list(
        "01-26" = "Republic Day", "08-15" = "Independence Day",
        "10-02" = "Gandhi Jayanti", "12-25" = "Christmas",
        "04-14" = "Ambedkar Jayanti", "01-14" = "Makar Sankranti"
      )
      dfs <- append(dfs, list(expand_fixed_holidays(input$fixed_holidays, years, label_map)))
    }
    
    if (nrow(manual_fixed() %||% tibble()) > 0) dfs <- append(dfs, list(manual_fixed()))
    if (nrow(manual_movable() %||% tibble()) > 0) dfs <- append(dfs, list(manual_movable()))
    
    compiled_holidays(
      bind_rows(compiled_holidays(), bind_rows(dfs)) %>%
        distinct(ds, holiday, .keep_all = TRUE) %>%
        arrange(ds)
    )
    
    showModal(modalDialog(
      title = "✅ Holiday list built",
      sprintf("The working holiday list now has %d holiday dates (Sundays, fixed holidays and manual entries). Review it on step 4.",
              nrow(compiled_holidays())),
      easyClose = TRUE,
      footer = modalButton("OK")
    ))
  })
  
  # ➕ Manual Entry
  observeEvent(input$add_manual, {
    req(input$manual_date)
    if (!notify_unless(isTruthy(trimws(input$manual_label)), "Enter a holiday name.")) return()
    type <- input$manual_type
    date <- input$manual_date
    label <- input$manual_label
    years <- seq(input$holiday_years[1], input$holiday_years[2])
    store <- if (type == "fixed") manual_fixed() else manual_movable()
    
    updated <- apply_manual_entry(store, date, label, type, years)
    if (type == "fixed") manual_fixed(updated) else manual_movable(updated)
  })
  
  # ❌ Remove Manual Entries
  observeEvent(input$remove_manual, {
    selected <- input$manual_table_rows_selected
    if (length(selected) > 0) {
      fixed <- manual_fixed() %||% tibble()
      movable <- manual_movable() %||% tibble()
      combined <- bind_rows(
        mutate(fixed, type = "fixed"),
        mutate(movable, type = "movable")
      )
      filtered <- combined[-selected, ]
      manual_fixed(filtered %>% filter(type == "fixed") %>% select(-type))
      manual_movable(filtered %>% filter(type == "movable") %>% select(-type))
    }
  })
  
  # 📌 Apply Window Settings
  observeEvent(input$apply_window, {
    if (!notify_unless(isTruthy(input$window_label),
                       "Build the holiday list first (🧮 Build holiday list on step 1); windows apply to holidays in that list.")) return()
    # Prophet requires lower_window <= 0 and upper_window >= 0; catch a
    # positive "days before" here instead of failing later at forecast time.
    if (!is.numeric(input$lower_window) || is.na(input$lower_window) || input$lower_window > 0 ||
        !is.numeric(input$upper_window) || is.na(input$upper_window) || input$upper_window < 0) {
      showNotification("⚠️ Days before must be 0 or negative (e.g. -2 for two days before); days after must be 0 or positive.",
                       type = "warning", duration = 8)
      return()
    }
    updated <- (holiday_windows() %||% empty_windows()) %>%
      filter(holiday != input$window_label) %>%
      bind_rows(tibble(
        holiday = input$window_label,
        lower_window = input$lower_window,
        upper_window = input$upper_window
      ))
    holiday_windows(updated)
  })
  
  # 🎯 Update Window Selector
  observe({
    updateSelectInput(session, "window_label", choices = unique(compiled_holidays()$holiday))
  })
  
  # ✏️ Apply Label Edit
  observeEvent(input$apply_edit, {
    selected <- input$final_holiday_table_rows_selected
    if (!notify_unless(length(selected) == 1, "Select one row in the working holiday list to rename.")) return()
    if (!notify_unless(isTruthy(trimws(input$edit_label)), "Type the new name first.")) return()
    compiled_holidays(apply_label_edit(compiled_holidays(), selected, input$edit_label))
  })
  
  output$selected_holiday_info <- renderText({
    selected <- input$final_holiday_table_rows_selected
    if (length(selected) == 1) {
      row <- compiled_holidays()[selected, ]
      paste("Selected:", format(row$ds, "%Y-%m-%d"), "-", row$holiday)
    } else {
      "Select a row in the table above to rename that holiday."
    }
  })
  
  # ✅ Use the working list for forecasting ("finalize")
  # ignoreInit: this used to be a checkbox whose initial FALSE value fired the
  # observer at module start-up, wiping the working state to NULL, showing
  # "finalized" on the Data tab and crashing "Apply window". It's now an
  # action button; ignoreInit keeps start-up from ever counting as a click.
  observeEvent(input$confirm_finalize, {
    holidays <- compiled_holidays() %||% empty_holidays()
    if (nrow(holidays) == 0) {
      showNotification(
        "⚠️ The working holiday list is empty. Build it first with 🧮 Build holiday list on step 1. Forecasts run without holidays until a list is in use.",
        type = "warning", duration = 10
      )
      return()
    }
    final_holidays(apply_window_settings(holidays, holiday_windows() %||% empty_windows()))
    compiled_holidays(empty_holidays())
    manual_fixed(empty_holidays())
    manual_movable(empty_holidays())
    holiday_windows(empty_windows())
    removeModal()
    app_log(sprintf("holiday list in use: %d dates, %d distinct holidays",
                    nrow(final_holidays()), dplyr::n_distinct(final_holidays()$holiday)), session = session)
    showNotification(
      sprintf("✅ Holiday list in use for forecasting (%d holiday dates). It applies to the next forecast you generate.", nrow(final_holidays())),
      type = "message"
    )
  }, ignoreInit = TRUE)
  
  # 📊 Holiday Summary Stats
  output$holiday_summary_stats <- renderPrint({
    df <- compiled_holidays() %||% tibble()
    if (nrow(df) == 0) {
      cat("The working holiday list is empty.")
    } else {
      summary_df <- df %>% count(holiday) %>% arrange(desc(n))
      print(summary_df)  # ← no extra arguments
    }
  })
  
  # 🔍 Contingency Analysis
  output$holiday_contingency_ui <- renderUI({
    req(input$enable_contingency == "yes", dataset(), compiled_holidays())
    
    data <- dataset()
    holidays <- compiled_holidays()
    
    # 🟢 Holidays with non-zero y
    nonzero_tbl <- inner_join(holidays, data, by = "ds") %>%
      filter(y > 0) %>%
      select(ds, holiday, y) %>%
      arrange(desc(y))
    
    nonzero_ui <- tagList(
      h5("📊 Holidays that fall on days with data (value > 0)"),
      if (nrow(holidays) == 0) {
        helpText("The working holiday list is empty: build it on step 1 first.")
      } else if (nrow(nonzero_tbl) == 0) {
        helpText(sprintf("None of the holidays fall on a day with data > 0. Your data runs %s to %s; check the year range on step 1.",
                         format(as.Date(min(data$ds))), format(as.Date(max(data$ds)))))
      } else {
        DT::datatable(nonzero_tbl, colnames = c("Date", "Holiday", "Value"),
                      options = list(pageLength = 5, scrollX = TRUE))
      }
    )
    
    # 🟠 Dates always zero or missing
    data_by_md <- data %>%
      mutate(md = format(ds, "%m-%d")) %>%
      group_by(md) %>%
      summarise(
        all_zero = all(y == 0, na.rm = TRUE),
        all_missing = all(is.na(y)),
        .groups = "drop"
      ) %>%
      filter(all_zero | all_missing) %>%
      mutate(flag = ifelse(all_missing, "Missing every year", "Zero every year"))
    
    zero_dates <- data_by_md %>%
      crossing(year = unique(lubridate::year(data$ds))) %>%
      mutate(ds = as.Date(paste0(year, "-", md), format = "%Y-%m-%d")) %>%
      select(ds, flag)
    
    zero_ui <- tagList(
      h5("🧭 Calendar dates that are zero or missing every year"),
      if (nrow(zero_dates) == 0) {
        helpText("No calendar date is zero or missing in every year of your data.")
      } else {
        DT::datatable(zero_dates, colnames = c("Date", "Pattern"), options = list(pageLength = 5, scrollX = TRUE))
      }
    )
    
    tagList(nonzero_ui, hr(), zero_ui)
  })
  
  # 📥 Final Download
  output$download_holidays <- downloadHandler(
    filename = function() paste0("final_holidays_", Sys.Date(), ".csv"),
    content = function(file) {
      req(final_holidays())
      write.csv(final_holidays(), file, row.names = FALSE)
    }
  )

  # A small worked example of the movable-holiday file format (date + label
  # columns), so the upload widget isn't the only guidance before a first try.
  output$download_example_holidays <- downloadHandler(
    filename = function() "example_holidays.csv",
    content = function(file) {
      file.copy("data/example_holidays.csv", file)
    }
  )

  # 📋 Manual Table
  output$manual_table <- renderDT({
    fixed <- manual_fixed() %||% tibble(ds = as.Date(character()), holiday = character())
    movable <- manual_movable() %||% tibble(ds = as.Date(character()), holiday = character())
    datatable(
      bind_rows(
        mutate(fixed, type = "every year"),
        mutate(movable, type = "once")
      ),
      selection = "multiple",
      colnames = c("Date", "Holiday", "Repeats"),
      options = list(scrollX = TRUE, pageLength = 5)
    )
  })
  
  output$window_table <- renderDT({
    windows <- holiday_windows() %||% empty_windows()
    datatable(windows, colnames = c("Holiday", "Days before", "Days after"),
              options = list(pageLength = 5, dom = "tp"))
  })
  
  output$final_holiday_table <- renderDT({
    datatable(compiled_holidays() %||% empty_holidays(),
              selection = "single",
              colnames = c("Date", "Holiday"),
              options = list(
                scrollX = TRUE,
                pageLength = 10,
                order = list(list(0, 'asc'))  # default sort by first column (ds)
              )
    )
  })
  
  output$holiday_summary <- renderText({
    paste("Holiday dates in the working list:", nrow(compiled_holidays() %||% empty_holidays()))
  })

  output$final_holiday_status <- renderText({
    if (is.null(final_holidays())) {
      "No holiday list in use: forecasts run without holiday effects."
    } else {
      sprintf("In use for forecasting: %d holiday dates (%d distinct holidays).",
              nrow(final_holidays()), dplyr::n_distinct(final_holidays()$holiday))
    }
  })
  
  return(final_holidays)
}