forecast_server <- function(input, output, session, dataset, final_holidays) {
  
  # 🔹 Reactive store for main forecast results
  forecast_data <- reactiveVal(NULL)
  
  # 🔹 Generate primary forecast
  observeEvent(input$forecast_btn, {
    # Holidays are optional: no finalized list (NULL) or an empty one means
    # "forecast without holidays" rather than silently doing nothing.
    req(dataset(), input$date_agg)
    holidays_df <- final_holidays()
    if (!is.null(holidays_df) && nrow(holidays_df) == 0) holidays_df <- NULL
    if (is.null(holidays_df)) {
      showNotification("ℹ️ No holiday list has been finalized, so this forecast runs without holiday effects.",
                       type = "message", duration = 6)
    }

    df <- dataset()
    test_cutoff <- max(df$ds) %m-% months(input$manual_test_months)
    train_df <- df[df$ds <= test_cutoff, ]
    test_df  <- df[df$ds > test_cutoff, ]

    # Prophet needs at least two training rows; say why instead of surfacing
    # Prophet's own "Dataframe has less than 2 non-NA rows" error (which is
    # what the bundled 1-year demo dataset hit with the 12-month default).
    if (nrow(train_df) < 2) {
      showNotification(
        sprintf(
          "❌ The Manual Test Window (%s months, under 🧪 Evaluation Settings) covers all of your data (%s to %s), leaving nothing to train on. Make the test window shorter and generate the forecast again.",
          input$manual_test_months, format(as.Date(min(df$ds))), format(as.Date(max(df$ds)))
        ),
        type = "error", duration = NULL
      )
      return()
    }

    horizon_periods <- convert_months_to_horizon(input$horizon_months, input$date_agg)

    result <- tryCatch({
      prepare_forecast(
        data            = train_df,
        holidays_df     = holidays_df,
        cp              = input$cp,
        season          = input$season,
        holiday         = input$holiday,
        horizon         = horizon_periods,
        exclude_sundays = input$sundays,
        yearly          = input$add_yearly,
        weekly          = input$add_weekly,
        daily           = input$add_daily,
        freq            = seq_unit_for(input$date_agg)
      ) |> append(list(train = train_df, test = test_df))
    }, error = function(e) {
      showNotification(paste("❌ Forecast failed:", e$message), type = "error")
      NULL
    })
    
    forecast_data(result)
  })
  
  # 📈 Forecast Plot
  output$forecastPlot <- renderPlot({
    validate(need(forecast_data(), "Run a forecast to see results here."))
    plot_forecast(
      model             = forecast_data()$model,
      forecast          = forecast_data()$forecast,
      show_trend        = input$show_trend,
      show_uncertainty  = input$show_uncertainty,
      show_holidays     = input$show_holidays,
      show_changepoints = input$show_changepoints,
      trend_color       = input$trend_color,
      uncertainty_color = input$uncertainty_color,
      holiday_color     = input$holiday_color,
      changepoint_color = input$changepoint_color
    )
  })
  
  # 📥 Download Plot
  output$downloadPlot <- downloadHandler(
    filename = function() paste0("forecast_", Sys.Date(), ".png"),
    content = function(file) {
      ggsave(
        file,
        plot = plot_forecast(
          model             = forecast_data()$model,
          forecast          = forecast_data()$forecast,
          show_trend        = input$show_trend,
          show_uncertainty  = input$show_uncertainty,
          show_holidays     = input$show_holidays,
          show_changepoints = input$show_changepoints,
          trend_color       = input$trend_color,
          uncertainty_color = input$uncertainty_color,
          holiday_color     = input$holiday_color,
          changepoint_color = input$changepoint_color
        ),
        width = 12, height = 6, dpi = 300
      )
    }
  )
  
  # 📋 Evaluation Metrics
  observeEvent(input$eval_btn, {
    req(forecast_data())
    f <- forecast_data()
    
    output$metricsTable <- DT::renderDT({
      req(forecast_data())
      f <- forecast_data()
      
      # ⏳ Compute metrics across subsets
      metrics <- bind_rows(
        safe_compute_metrics(f$forecast, f$train, "Train"),
        safe_compute_metrics(f$forecast, f$train[f$train$ds > (max(f$train$ds) %m-% months(6)), ], "Last 6 Months"),
        safe_compute_metrics(f$forecast, f$train[f$train$ds > (max(f$train$ds) %m-% years(2)), ], "Last 2 Years"),
        safe_compute_metrics(f$forecast, f$test, "Manual Entry")
      )
      
      # 🧮 Pivot long → wide
      metrics_wide <- tidyr::pivot_wider(
        metrics,
        names_from = Set,
        values_from = Value
      ) %>% 
        dplyr::select(Metric, `Train`, `Last 6 Months`, `Last 2 Years`, `Manual Entry`)
      
      DT::datatable(metrics_wide, options = list(dom = 't', scrollX = TRUE))
    })
  })
  # 📈 Plotly Interactive Forecast
  observeEvent(input$plotly_btn, {
    req(input$enable_plotly, forecast_data())
    f <- forecast_data()
    
    output$plotlyForecast <- renderPlotly({
      plot_ly() %>%
        add_lines(data = f$forecast, x = ~ds, y = ~yhat, name = "Forecast", line = list(color = "#d95f02")) %>%
        add_ribbons(data = f$forecast, x = ~ds, ymin = ~yhat_lower, ymax = ~yhat_upper,
                    name = "Uncertainty", fillcolor = "rgba(31,158,119,0.2)", line = list(width = 0)) %>%
        add_lines(data = f$train, x = ~ds, y = ~y, name = "Actual", line = list(color = "#1b9e77")) %>%
        layout(
          title = "Interactive Forecast",
          xaxis = list(
            title = "Date",
            rangeselector = list(
              buttons = list(
                list(count = 6, label = "6m", step = "month", stepmode = "backward"),
                list(count = 1, label = "1y", step = "year", stepmode = "backward"),
                list(step = "all")
              ),
              x = 0.5,
              xanchor = "center"
            ),
            range = c(max(f$forecast$ds) %m-% months(6), max(f$forecast$ds))
          ),
          yaxis = list(title = "Value"),
          hovermode = "x unified"
        )
    })
  })

  return(list(forecast_data = forecast_data))
}