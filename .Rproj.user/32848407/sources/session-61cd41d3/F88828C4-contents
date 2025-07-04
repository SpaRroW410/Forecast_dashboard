data_import_server <- function(input, output, session) {
  
  main_data <- import_panel_server("main")
  pop_data  <- import_panel_server("pop")
  
  # Update column selectors when main data is uploaded
  observeEvent(main_data(), {
    req(main_data())
    colnames <- names(main_data())
    updateSelectInput(session, "model_date_col", choices = colnames)
    updateSelectInput(session, "model_value_col", choices = colnames)
  })
  
  # Dynamic UI for population column selectors
  output$pop_col_ui <- renderUI({
    req(pop_data())
    tagList(
      selectInput("pop_date_col", "Date or Year Column", choices = names(pop_data())),
      selectInput("pop_val_col",  "Population Column", choices = names(pop_data()))
    )
  })
  
  # Preview main dataset
  output$main_preview <- renderDT({
    req(main_data())
    datatable(main_data(), options = list(scrollX = TRUE, pageLength = 5))
  })
  
  # Preview population dataset
  output$pop_preview <- renderDT({
    req(pop_data())
    datatable(pop_data(), options = list(scrollX = TRUE, pageLength = 5))
  })
  
  # Reactive processed dataset
  dataset <- reactive({
    req(main_data(), input$model_date_col)
    
    # Ensure value column is selected for aggregated data
    if (input$data_type == "agg" && is.null(input$model_value_col)) {
      return(NULL)
    }
    
    # Check if population inputs are ready
    pop_ready <- !is.null(input$pop_val_col) && !is.null(input$pop_date_col)
    
    tryCatch({
      df <- process_uploaded_data(
        data            = main_data(),
        type            = input$data_type,
        date_col        = input$model_date_col,
        value_col       = if (input$data_type == "agg") input$model_value_col else NULL,
        pop_df          = if (pop_ready) pop_data() else NULL,
        pop_date_col    = if (pop_ready) input$pop_date_col else NULL,
        pop_value_col   = if (pop_ready) input$pop_val_col else NULL,
        unit_divisor    = input$unit_scale,
        pop_multiplier  = input$pop_multiplier,
        date_agg        = input$date_agg,
        pop_freq        = input$pop_freq
      )
      
      return(df)
    }, error = function(e) {
      showNotification(paste("⚠️ Error:", e$message), type = "error")
      NULL
    })
  })
  
  # Preview processed dataset
  output$dataPreview <- renderDT({
    req(dataset())
    df <- dataset()
    df$ds <- format(df$ds, "%Y-%m-%d")
    datatable(df, options = list(scrollX = TRUE, pageLength = 10))
  })
  
  # Download processed dataset
  output$download_processed <- downloadHandler(
    filename = function() paste0("processed_dataset_", Sys.Date(), ".csv"),
    content = function(file) {
      write.csv(dataset(), file, row.names = FALSE)
    }
  )
  
  return(dataset)
}