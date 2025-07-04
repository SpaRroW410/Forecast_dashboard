source("helpers/holidays_helpers.R",local = TRUE)

holidays_server <- function(input, output, session, dataset) {
  movable_holidays <- import_panel_server("hol")
  manual_fixed <- reactiveVal(tibble(ds = as.Date(character()), holiday = character()))
  manual_movable <- reactiveVal(tibble(ds = as.Date(character()), holiday = character()))
  final_holiday_store <- reactiveVal(tibble(ds = as.Date(character()), holiday = character()))
  holiday_windows <- reactiveVal(tibble(holiday = character(), lower_window = integer(), upper_window = integer()))
  
  observe({
    dfs <- list()
    if (isTRUE(input$include_sundays)) dfs <- append(dfs, list(generate_sundays(dataset()$ds)))
    if (!is.null(input$fixed_holidays)) {
      years <- seq(input$holiday_years[1], input$holiday_years[2])
      label_map <- list(
        "01-26" = "Republic Day",
        "08-15" = "Independence Day",
        "10-02" = "Gandhi Jayanti",
        "12-25" = "Christmas",
        "04-14" = "Ambedkar Jayanti",
        "01-14" = "Makar Sankranti"
      )
      dfs <- append(dfs, list(expand_fixed_holidays(input$fixed_holidays, years, label_map)))
    }
    if (!is.null(movable_holidays()) && !is.null(input$date_col) && !is.null(input$label_col)) {
      dfs <- append(dfs, list(parse_movable_holidays(movable_holidays(), input$date_col, input$label_col)))
    }
    if (nrow(manual_fixed()) > 0) dfs <- append(dfs, list(manual_fixed()))
    if (nrow(manual_movable()) > 0) dfs <- append(dfs, list(manual_movable()))
    final_holiday_store(bind_rows(dfs) %>% distinct(ds, holiday, .keep_all = TRUE) %>% arrange(ds))
  })
  
  observeEvent(input$add_manual, {
    req(input$manual_date, input$manual_label)
    years <- seq(input$holiday_years[1], input$holiday_years[2])
    if (input$manual_type == "fixed") {
      manual_fixed(apply_manual_entry(manual_fixed(), input$manual_date, input$manual_label, "fixed", years))
    } else {
      manual_movable(apply_manual_entry(manual_movable(), input$manual_date, input$manual_label, "movable"))
    }
  })
  
  observeEvent(input$remove_manual, {
    selected <- input$manual_table_rows_selected
    if (length(selected) > 0) {
      combined <- bind_rows(
        mutate(manual_fixed(), type = "fixed"),
        mutate(manual_movable(), type = "movable")
      )
      filtered <- combined[-selected, ]
      manual_fixed(filtered %>% filter(type == "fixed") %>% select(-type))
      manual_movable(filtered %>% filter(type == "movable") %>% select(-type))
    }
  })
  
  observeEvent(input$apply_edit, {
    selected <- input$final_holiday_table_rows_selected
    if (length(selected) == 1 && trimws(input$edit_label) != "") {
      updated <- apply_label_edit(final_holiday_store(), selected, input$edit_label)
      final_holiday_store(updated)
    }
  })
  
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
  
  observe({
    updateSelectInput(session, "window_label", choices = unique(final_holiday_store()$holiday))
  })
  
  output$movable_preview <- renderDT({
    req(movable_holidays())
    datatable(movable_holidays(), options = list(scrollX = TRUE, pageLength = 5))
  })
  
  output$movable_date_col <- renderUI({
    req(movable_holidays())
    selectInput("date_col", "Select Date Column (ds):", choices = names(movable_holidays()))
  })
  
  output$movable_label_col <- renderUI({
    req(movable_holidays())
    selectInput("label_col", "Select Label Column (holiday):", choices = names(movable_holidays()))
  })
  
  output$manual_table <- renderDT({
    datatable(
      bind_rows(
        mutate(manual_fixed(), type = "fixed"),
        mutate(manual_movable(), type = "movable")
      ),
      selection = "multiple",
      options = list(
        scrollX = TRUE,
        pageLength = 5,
        dom = '<"top"l><"bottom"f>rtip'  # l = length, f = filter/search
      )
    )
  })
  
  
  output$final_holiday_table <- renderDT({
    datatable(final_holiday_store(), selection = "single", options = list(scrollX = TRUE, dom = 't'))
  })
  
  output$selected_holiday_info <- renderPrint({
    selected <- input$final_holiday_table_rows_selected
    if (length(selected) == 1) {
      row <- final_holiday_store()[selected, ]
      paste("Selected:", format(row$ds, "%Y-%m-%d"), "-", row$holiday)
    } else {
      "Select a row from the table above to edit its label."
    }
  })
  
  
  
  output$window_table <- renderDT({
    datatable(holiday_windows(), options = list(pageLength = 5))
  })
  
  output$holiday_summary <- renderPrint({
    paste("Total holidays:", nrow(final_holiday_store()))
  })
  
  final_holidays <- reactive({
    apply_window_settings(final_holiday_store(), holiday_windows())
  })
  
  output$download_holidays <- downloadHandler(
    filename = function() {
      paste0("final_holidays_", Sys.Date(), ".csv")
    },
    content = function(file) {
      req(final_holidays())
      write.csv(final_holidays(), file, row.names = FALSE)
    }
  )
  
  output$holiday_contingency <- renderDT({
    req(dataset(), final_holidays())
    
    data <- dataset()
    holidays <- final_holidays()
    
    
    
    # 1️⃣ Holidays with non-zero values
    overlap <- inner_join(holidays, data, by = "ds") %>%
      filter(y > 0) %>%
      mutate(flag = "Holiday with non-zero data")
    
    # 2️⃣ Dates with 0 or missing frequency every year
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
    
    combined <- bind_rows(
      select(overlap, ds, holiday, flag),
      left_join(zero_dates, holidays, by = "ds") %>% select(ds, holiday, flag)
    ) %>%
      arrange(ds)
    
    datatable(combined, options = list(scrollX = TRUE, pageLength = 10))
  })
  
  return(final_holidays)
}