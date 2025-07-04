arima_server <- function(input, output, session, dataset_reactive) {
  
  # Fill missing dates with NA
  arima_ready_data <- reactive({
    req(dataset_reactive())
    df <- dataset_reactive()
    full_seq <- tibble(ds = seq(min(df$ds), max(df$ds), by = "day"))  # or use input$date_agg if needed
    df_filled <- full_seq %>%
      left_join(df, by = "ds") %>%
      arrange(ds)
    return(df_filled)
  })
  
  output$arima_data_preview <- renderDT({
    req(arima_ready_data())
    datatable(arima_ready_data(), options = list(scrollX = TRUE, pageLength = 10))
  })
  
  observeEvent(input$fit_arima, {
    req(arima_ready_data())
    df <- arima_ready_data()
    
    # Impute missing values (simple forward fill or interpolation)
    df$y <- zoo::na.approx(df$y, na.rm = FALSE)
    
    # Fit ARIMA
    ts_data <- ts(df$y, frequency = 365)  # adjust frequency if needed
    model <- forecast::auto.arima(ts_data)
    
    output$arima_summary <- renderPrint({
      summary(model)
    })
    
    output$arima_plot <- renderPlot({
      forecast::autoplot(forecast::forecast(model, h = 30))
    })
  })
}