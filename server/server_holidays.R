source("helpers/holidays_helpers.R", local = TRUE)

holidays_server <- function(input, output, session, dataset) {
  movable_holidays    <- import_panel_server("hol")
  manual_fixed        <- reactiveVal(tibble(ds = as.Date(character()), holiday = character()))
  manual_movable      <- reactiveVal(tibble(ds = as.Date(character()), holiday = character()))
  compiled_holidays   <- reactiveVal(tibble(ds = as.Date(character()), holiday = character()))
  holiday_windows     <- reactiveVal(tibble(holiday = character(), lower_window = integer(), upper_window = integer()))
  final_holidays      <- reactiveVal(NULL)
  
  # 🗂 Column mapping (restored)
  output$movable_date_col <- renderUI({
    req(movable_holidays())
    selectInput("date_col", "Date Column (ds):", choices = names(movable_holidays()))
  })
  
  output$movable_label_col <- renderUI({
    req(movable_holidays())
    selectInput("label_col", "Label Column (holiday):", choices = names(movable_holidays()))
  })
  
  # ✅ Finalize Movable Holidays
  observeEvent(input$finalize_movable, {
    req(movable_holidays(), input$date_col, input$label_col)
    showNotification("⏳ Finalizing movable holidays...", type = "default", duration = 2)
    
    df <- parse_movable_holidays(movable_holidays(), input$date_col, input$label_col)
    compiled_holidays(bind_rows(compiled_holidays(), df) %>% distinct())
    
    showModal(modalDialog(
      title = "✅ Movable Holidays Added",
      "Your movable holidays have been successfully validated and added to the combined list.",
      easyClose = TRUE,
      footer = modalButton("OK")
    ))
  })
  
  # 🧮 Compile Sundays + Fixed Holidays
  observeEvent(input$compile_fixed_holidays, {
    showNotification("⏳ Compiling Sundays and Fixed Holidays...", type = "default", duration = 2)
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
      title = "✅ Holidays Compiled",
      "Your selected Sundays and fixed holidays have been compiled successfully.",
      easyClose = TRUE,
      footer = modalButton("OK")
    ))
  })
  
  # ➕ Manual Entry
  observeEvent(input$add_manual, {
    req(input$manual_date, trimws(input$manual_label) != "")
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
    req(input$window_label)
    updated <- holiday_windows() %>%
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
    if (length(selected) == 1 && trimws(input$edit_label) != "") {
      updated <- apply_label_edit(compiled_holidays(), selected, input$edit_label)
      compiled_holidays(updated)
    }
  })
  
  output$selected_holiday_info <- renderPrint({
    selected <- input$final_holiday_table_rows_selected
    if (length(selected) == 1) {
      row <- compiled_holidays()[selected, ]
      paste("Selected:", format(row$ds, "%Y-%m-%d"), "-", row$holiday)
    } else {
      "Select a row from the preview table to edit its label."
    }
  })
  
  # ✅ Finalize Holidays
  observeEvent(input$confirm_finalize, {
    final_holidays(apply_window_settings(compiled_holidays(), holiday_windows()))
    compiled_holidays(NULL)
    manual_fixed(NULL)
    manual_movable(NULL)
    holiday_windows(NULL)
    removeModal()
    showNotification("✅ Final holiday list finalized.", type = "message")
  })
  
  # 📊 Holiday Summary Stats
  output$holiday_summary_stats <- renderPrint({
    df <- compiled_holidays() %||% tibble()
    if (nrow(df) == 0) {
      cat("No holiday entries found.")
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
      h5("📊 Holidays with Non-Zero Data"),
      DT::datatable(nonzero_tbl, options = list(pageLength = 5, scrollX = TRUE))
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
      h5("🧭 Dates Always Zero or Missing"),
      DT::datatable(zero_dates, options = list(pageLength = 5, scrollX = TRUE))
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
  
  # 📋 Manual Table
  output$manual_table <- renderDT({
    fixed <- manual_fixed() %||% tibble(ds = as.Date(character()), holiday = character())
    movable <- manual_movable() %||% tibble(ds = as.Date(character()), holiday = character())
    datatable(
      bind_rows(
        mutate(fixed, type = "fixed"),
        mutate(movable, type = "movable")
      ),
      selection = "multiple",
      options = list(scrollX = TRUE, pageLength = 5)
    )
  })
  
  output$window_table <- renderDT({
    datatable(holiday_windows() %||% tibble(), options = list(pageLength = 5))
  })
  
  output$final_holiday_table <- renderDT({
    datatable(compiled_holidays() %||% tibble(),
              selection = "single",
              options = list(
                scrollX = TRUE,
                pageLength = 10,
                order = list(list(0, 'asc'))  # default sort by first column (ds)
              )
    )
  })
  
  output$holiday_summary <- renderPrint({
    paste("Total holidays:", nrow(compiled_holidays()))
  })
  
  return(final_holidays)
}