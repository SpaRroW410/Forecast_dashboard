forecast_server <- function(input, output, session, dataset, final_holidays) {
  
  forecast_data <- eventReactive(input$forecast_btn, {
    req(dataset(), input$date_agg, input$horizon_months)
    
    total_data <- dataset()
    
    # Calculate test window cutoff
    manual_months <- input$manual_test_months
    test_cutoff <- max(total_data$ds) %m-% months(manual_months)
    
    # Warn if manual window is too large
    total_months <- interval(min(total_data$ds), max(total_data$ds)) %/% months(1)
    if (manual_months > total_months / 2) {
      showNotification("⚠️ Manual test window exceeds half the dataset. Metrics may be unreliable.", type = "warning")
    }
    
    # Split data
    train_data <- total_data[total_data$ds <= test_cutoff, ]
    test_data  <- total_data[total_data$ds > test_cutoff, ]
    
    horizon_days <- convert_months_to_horizon(input$horizon_months, input$date_agg)
    
    tryCatch({
      withProgress(message = "Generating forecast...", value = 0.5, {
        prepare_forecast(
          data            = train_data,
          holidays_df     = final_holidays(),
          cp              = input$cp,
          season          = input$season,
          holiday         = input$holiday,
          horizon         = horizon_days,
          exclude_sundays = input$sundays,
          yearly          = input$add_yearly,
          weekly          = input$add_weekly,
          daily           = input$add_daily
        ) |> append(list(test = test_data))
      })
    }, error = function(e) {
      showNotification(paste("❌ Forecast failed:", e$message), type = "error")
      NULL
    })
  })
  
  output$forecastPlot <- renderPlot({
    req(forecast_data())
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
  
  output$metricsTable <- renderTable({
    req(forecast_data())
    
    forecast_df <- forecast_data()$forecast
    train_df    <- forecast_data()$train
    test_df     <- forecast_data()$test
    
    six_months_df <- train_df[train_df$ds > (max(train_df$ds) %m-% months(6)), ]
    two_years_df  <- train_df[train_df$ds > (max(train_df$ds) %m-% years(2)), ]
    manual_df     <- test_df
    
    bind_rows(
      safe_compute_metrics(forecast_df, train_df, "Train (In-sample)"),
      safe_compute_metrics(forecast_df, six_months_df, "Last 6 Months"),
      safe_compute_metrics(forecast_df, two_years_df, "Last 2 Years"),
      safe_compute_metrics(forecast_df, manual_df, "Manual")
    )
  })
  
  output$metricsPlot <- renderPlot({
    req(forecast_data())
    
    forecast_df <- forecast_data()$forecast
    train_df    <- forecast_data()$train
    test_df     <- forecast_data()$test
    
    six_months_df <- train_df[train_df$ds > (max(train_df$ds) %m-% months(6)), ]
    two_years_df  <- train_df[train_df$ds > (max(train_df$ds) %m-% years(2)), ]
    manual_df     <- test_df
    
    metrics <- bind_rows(
      safe_compute_metrics(forecast_df, train_df, "Train"),
      safe_compute_metrics(forecast_df, six_months_df, "6M"),
      safe_compute_metrics(forecast_df, two_years_df, "2Y"),
      safe_compute_metrics(forecast_df, manual_df, "Manual")
    )
    
    ggplot(metrics, aes(x = Metric, y = Value, fill = Set)) +
      geom_col(position = "dodge") +
      labs(title = "Forecast Evaluation Metrics", y = "Value", x = NULL) +
      theme_minimal(base_family = "serif") +
      theme(legend.position = "top")
  })
  
  output$seasonalityPlot <- renderPlot({
  req(forecast_data())
  prophet::prophet_plot_components(forecast_data()$model, forecast_data()$forecast)
})
  

  output$comparisonPlot <- renderPlot({
    req(dataset(), final_holidays())
    
    cp_vals <- c(input$cp1, input$cp2)
    season_vals <- c(input$season1, input$season2)
    
    priors <- expand.grid(cp = cp_vals, season = season_vals)
    plots <- list()
    
    for (i in seq_len(nrow(priors))) {
      model_result <- prepare_forecast(
        data = dataset(),
        holidays_df = final_holidays(),
        cp = priors$cp[i],
        season = priors$season[i],
        holiday = input$holiday,
        horizon = convert_months_to_horizon(input$horizon_months, input$date_agg),
        exclude_sundays = input$sundays,
        yearly = input$add_yearly,
        weekly = input$add_weekly,
        daily = input$add_daily
      )
      
      p <- plot_forecast(
        model = model_result$model,
        forecast = model_result$forecast,
        show_trend = TRUE,
        show_uncertainty = FALSE
      ) +
        ggtitle(paste("CP:", priors$cp[i], "| Season:", priors$season[i]))
      
      plots[[i]] <- p
    }
    
    patchwork::wrap_plots(plots, ncol = 2)
  })
  
  output$comparisonPlot <- renderPlot({
    req(dataset(), final_holidays())
    
    priors <- expand.grid(cp = c(0.01, 0.5), season = c(1, 20))
    plots <- list()
    
    for (i in seq_len(nrow(priors))) {
      model_result <- prepare_forecast(
        data = dataset(),
        holidays_df = final_holidays(),
        cp = priors$cp[i],
        season = priors$season[i],
        holiday = input$holiday,
        horizon = convert_months_to_horizon(input$horizon_months, input$date_agg),
        exclude_sundays = input$sundays,
        yearly = input$add_yearly,
        weekly = input$add_weekly,
        daily = input$add_daily
      )
      
      p <- plot_forecast(
        model = model_result$model,
        forecast = model_result$forecast,
        show_trend = TRUE,
        show_uncertainty = FALSE
      ) +
        ggtitle(paste("CP:", priors$cp[i], "| Season:", priors$season[i]))
      
      plots[[i]] <- p
    }
    
    patchwork::wrap_plots(plots, ncol = 2)
  })
  
  output$plotlyForecast <- renderPlotly({
    req(forecast_data())
    
    forecast_df <- forecast_data()$forecast
    model_df    <- forecast_data()$train
    
    plot_ly() %>%
      add_lines(data = forecast_df, x = ~ds, y = ~yhat, name = "Forecast", line = list(color = "#d95f02")) %>%
      add_ribbons(data = forecast_df, x = ~ds, ymin = ~yhat_lower, ymax = ~yhat_upper,
                  name = "Uncertainty", fillcolor = "rgba(31,158,119,0.2)", line = list(width = 0)) %>%
      add_lines(data = model_df, x = ~ds, y = ~y, name = "Actual", line = list(color = "#1b9e77")) %>%
      layout(title = "Interactive Forecast",
             xaxis = list(title = "Date", rangeselector = list(buttons = list(
               list(count = 6, label = "6m", step = "month", stepmode = "backward"),
               list(count = 1, label = "1y", step = "year", stepmode = "backward"),
               list(step = "all")
             ))),
             yaxis = list(title = "Value"),
             hovermode = "x unified")
  })
  
  output$downloadPlot <- downloadHandler(
    filename = function() paste0("forecast_", Sys.Date(), ".png"),
    content = function(file) {
      ggsave(
        file,
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
        ),
        width = 12, height = 6, dpi = 300
      )
    }
  )
}