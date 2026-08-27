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

    # Fit ARIMA -- non-seasonal order search only (see the SARIMA tab for a
    # seasonal fit); forecast::auto.arima()'s default is seasonal = TRUE,
    # which would otherwise make this tab and SARIMA the same model.
    ts_data <- ts(df$y, frequency = ts_frequency_for(input$date_agg))
    model <- forecast::auto.arima(ts_data, seasonal = FALSE)

    horizon_months <- if (is.null(input$horizon_months)) 24 else input$horizon_months
    date_agg <- if (is.null(input$date_agg)) "day" else input$date_agg
    horizon <- tryCatch(
      convert_months_to_horizon(horizon_months, date_agg),
      error = function(e) 30
    )

    output$arima_summary <- renderPrint({
      summary(model)
    })

    output$arima_plot <- renderPlot({
      forecast::autoplot(forecast::forecast(model, h = horizon))
    })
  })
}
