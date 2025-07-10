data_import_server <- function(input, output, session) {
  main_data <- import_panel_server("main")
  pop_data  <- import_panel_server("pop")
  
  main_transformed <- reactiveVal(NULL)
  final_dataset    <- reactiveVal(NULL)
  data_locked      <- reactiveVal(FALSE)
  pop_finalized    <- reactiveVal(FALSE)
  
  shinyjs::hide("model_value_col_wrapper")
  
  observeEvent(main_data(), {
    req(main_data())
    if (!data_locked()) {
      updateRadioButtons(session, "data_type", selected = character(0))
      updateSelectInput(session, "model_date_col", choices = NULL)
      updateSelectInput(session, "model_value_col", choices = NULL)
      shinyjs::hide("model_value_col_wrapper")
    }
  })
  
  observeEvent(input$data_type, {
    req(main_data(), input$data_type)
    if (!data_locked()) {
      cols <- names(main_data())
      updateSelectInput(session, "model_date_col", choices = cols)
      if (input$data_type == "agg") {
        updateSelectInput(session, "model_value_col", choices = cols)
        shinyjs::show("model_value_col_wrapper")
      } else {
        shinyjs::hide("model_value_col_wrapper")
      }
    }
  })
  
  observeEvent(input$transform_main, {
    req(main_data(), input$data_type, input$model_date_col, input$date_agg)
    if (input$data_type == "agg") req(input$model_value_col)
    
    df <- main_data()
    ds_col <- as.POSIXct(df[[input$model_date_col]])
    time_diffs <- diff(sort(ds_col))
    min_diff_secs <- min(as.numeric(time_diffs), na.rm = TRUE)
    
    agg_thresholds <- c(hour = 3600, day = 86400, week = 604800, month = 2419200)
    if (min_diff_secs > agg_thresholds[[input$date_agg]]) {
      showNotification("❌ Aggregation frequency is finer than data granularity.", type = "error")
      return()
    }
    
    result <- tryCatch({
      process_uploaded_data(
        data            = df,
        type            = input$data_type,
        date_col        = input$model_date_col,
        value_col       = if (input$data_type == "agg") input$model_value_col else NULL,
        pop_df          = NULL,
        pop_date_col    = NULL,
        pop_value_col   = NULL,
        unit_divisor    = 1,
        pop_multiplier  = 1,
        date_agg        = input$date_agg,
        pop_freq        = NULL
      )
    }, error = function(e) {
      showNotification(paste("⚠️ Error:", e$message), type = "error")
      NULL
    })
    
    main_transformed(result)
    data_locked(TRUE)
  })
  
  output$pop_col_ui <- renderUI({
    req(pop_data())
    tagList(
      selectInput("pop_date_col", "Date or Year Column", choices = names(pop_data())),
      selectInput("pop_val_col",  "Population Column", choices = names(pop_data()))
    )
  })
  
  observeEvent(input$finalize_population, {
    req(pop_data(), input$pop_val_col, input$pop_date_col)
    pop_finalized(TRUE)
    showNotification("✅ Population data finalized.", type = "message")
  })
  
  observeEvent(list(input$pop_val_col, input$pop_date_col, input$pop_freq), {
    pop_finalized(FALSE)
  })
  
  output$main_preview <- renderTable({
    req(main_transformed())
    head(main_transformed(), 5)
  })
  
  output$pop_preview <- renderTable({
    req(pop_data())
    head(pop_data(), 5)
  })
  
  observeEvent(input$process_data, {
    req(main_transformed())
    
    use_pop    <- input$use_population == "yes"
    pop_ready <- use_pop && !is.null(input$pop_val_col) && !is.null(input$pop_date_col)
    
    if (use_pop && !pop_finalized()) {
      showNotification("❗ Please finalize the population data before processing.", type = "warning")
      return()
    }
    
    if (use_pop && (!is.numeric(input$pop_multiplier) || input$pop_multiplier <= 0 ||
                    !is.numeric(input$unit_scale) || input$unit_scale <= 0)) {
      showNotification("⚠️ Please enter valid values for Population Multiplier and Unit Divisor.", type = "error")
      return()
    }
    
    result <- tryCatch({
      process_uploaded_data(
        data            = main_transformed(),
        type            = "agg",
        date_col        = "ds",
        value_col       = "y",
        pop_df          = if (pop_ready) pop_data() else NULL,
        pop_date_col    = if (pop_ready) input$pop_date_col else NULL,
        pop_value_col   = if (pop_ready) input$pop_val_col else NULL,
        unit_divisor    = if (use_pop) input$unit_scale else 1,
        pop_multiplier  = if (use_pop) input$pop_multiplier else 1,
        date_agg        = input$date_agg,
        pop_freq        = if (pop_ready) input$pop_freq else NULL
      )
    }, error = function(e) {
      showNotification(paste("⚠️ Error:", e$message), type = "error")
      NULL
    })
    
    final_dataset(result)
  })
  
  output$dataPreview <- renderTable({
    req(final_dataset())
    df <- final_dataset()
    df$ds <- format(df$ds, "%Y-%m-%d")
    head(df, 5)
  })
  
  output$download_processed <- downloadHandler(
    filename = function() paste0("processed_dataset_", Sys.Date(), ".csv"),
    content = function(file) {
      write.csv(final_dataset(), file, row.names = FALSE)
    }
  )
  
  return(list(
    is_ready = reactive({ !is.null(final_dataset()) }),
    dataset  = final_dataset
  ))
}