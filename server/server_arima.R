arima_server <- function(input, output, session, dataset_reactive, forecast_data_reactive) {

  # Map the app's aggregation choice to a sensible ts() seasonal frequency
  arima_ts_frequency <- function(date_agg) {
    freq_map <- c(hour = 24, day = 365, week = 52, month = 12)
    if (is.null(date_agg) || !(date_agg %in% names(freq_map))) date_agg <- "day"
    freq_map[[date_agg]]
  }

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
    ts_data <- ts(df$y, frequency = arima_ts_frequency(input$date_agg))
    model <- forecast::auto.arima(ts_data)

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

  # 📊 Prophet vs. ARIMA comparison — reuses the exact train/test split from
  # the Forecast & Evaluation tab so both models are judged on the same
  # held-out data.
  comparison_result <- reactiveVal(NULL)

  observeEvent(input$compare_models_btn, {
    req(forecast_data_reactive())
    f <- forecast_data_reactive()
    validate(need(!is.null(f$train) && !is.null(f$test), "Generate a Prophet forecast on the Forecast & Evaluation tab first."))

    result <- tryCatch({
      train_df <- f$train
      test_df  <- f$test
      if (nrow(test_df) < 2) stop("Not enough held-out test rows to compare models. Increase the manual test window on the Forecast & Evaluation tab.")

      train_df$y <- zoo::na.approx(train_df$y, na.rm = FALSE)
      ts_train <- ts(train_df$y, frequency = arima_ts_frequency(input$date_agg))
      arima_model <- forecast::auto.arima(ts_train)

      h <- nrow(test_df)
      arima_fc <- forecast::forecast(arima_model, h = h)

      arima_forecast_df <- tibble::tibble(
        ds   = test_df$ds[seq_len(h)],
        yhat = as.numeric(arima_fc$mean)[seq_len(h)]
      )

      prophet_metrics <- safe_compute_metrics(f$forecast, test_df, label = "Prophet")
      arima_metrics   <- safe_compute_metrics(arima_forecast_df, test_df, label = "ARIMA")

      dplyr::bind_rows(prophet_metrics, arima_metrics)
    }, error = function(e) {
      showNotification(paste("❌ Model comparison failed:", e$message), type = "error")
      NULL
    })

    comparison_result(result)
  })

  output$model_comparison_table <- DT::renderDT({
    validate(need(comparison_result(), "Click \"Compare Prophet vs ARIMA\" after generating a Prophet forecast on the Forecast & Evaluation tab."))
    wide <- comparison_result() %>%
      tidyr::pivot_wider(names_from = Set, values_from = Value) %>%
      dplyr::select(Metric, Prophet, ARIMA)
    DT::datatable(wide, options = list(dom = "t"))
  })

  output$model_comparison_summary <- renderText({
    req(comparison_result())
    rmse_row <- comparison_result()[comparison_result()$Metric == "RMSE", ]
    if (nrow(rmse_row) < 2 || any(is.na(rmse_row$Value))) {
      return("Not enough test data to determine the better model.")
    }
    best <- rmse_row$Set[which.min(rmse_row$Value)]
    paste0("Based on test-set RMSE, ", best, " is the better-fitting model for this dataset.")
  })
}
