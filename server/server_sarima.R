sarima_server <- function(input, output, session, dataset_reactive) {

  # Fill missing dates with NA -- same approach as the ARIMA tab.
  sarima_ready_data <- reactive({
    req(dataset_reactive())
    df <- dataset_reactive()
    full_seq <- tibble(ds = seq(min(df$ds), max(df$ds), by = "day"))
    df_filled <- full_seq %>%
      left_join(df, by = "ds") %>%
      arrange(ds)
    return(df_filled)
  })

  output$sarima_data_preview <- renderDT({
    req(sarima_ready_data())
    datatable(sarima_ready_data(), options = list(scrollX = TRUE, pageLength = 10))
  })

  observeEvent(input$fit_sarima, {
    req(sarima_ready_data())
    df <- sarima_ready_data()

    df$y <- zoo::na.approx(df$y, na.rm = FALSE)

    # Seasonal order search -- what makes this tab genuinely different from
    # the ARIMA tab's seasonal = FALSE fit.
    ts_data <- ts(df$y, frequency = ts_frequency_for(input$date_agg))
    model <- forecast::auto.arima(ts_data, seasonal = TRUE)

    horizon_months <- if (is.null(input$horizon_months)) 24 else input$horizon_months
    date_agg <- if (is.null(input$date_agg)) "day" else input$date_agg
    horizon <- tryCatch(
      convert_months_to_horizon(horizon_months, date_agg),
      error = function(e) 30
    )

    output$sarima_summary <- renderPrint({
      summary(model)
    })

    output$sarima_plot <- renderPlot({
      forecast::autoplot(forecast::forecast(model, h = horizon))
    })
  })
}
