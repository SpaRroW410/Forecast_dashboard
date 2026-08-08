forecast_server <- function(input, output, session, dataset, final_holidays) {
  
  # 🔹 Reactive store for main forecast results
  forecast_data <- reactiveVal(NULL)
  
  # 🔹 Generate primary forecast
  observeEvent(input$forecast_btn, {
    req(dataset(), final_holidays(), input$date_agg)
    
    df <- dataset()
    test_cutoff <- max(df$ds) %m-% months(input$manual_test_months)
    train_df <- df[df$ds <= test_cutoff, ]
    test_df  <- df[df$ds > test_cutoff, ]
    horizon_days <- convert_months_to_horizon(input$horizon_months, input$date_agg)
    
    result <- tryCatch({
      prepare_forecast(
        data            = train_df,
        holidays_df     = final_holidays(),
        cp              = input$cp,
        season          = input$season,
        holiday         = input$holiday,
        horizon         = horizon_days,
        exclude_sundays = input$sundays,
        yearly          = input$add_yearly,
        weekly          = input$add_weekly,
        daily           = input$add_daily
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
  

  
  # 📊 Combined Trend Comparison
  comparison_data <- reactiveVal(NULL)

  observeEvent(input$comparison_btn, {
    req(dataset(), final_holidays())

    prior_grid <- data.frame(
      Label  = c("A", "B", "C", "D"),
      cp     = c(input$cp1, input$cp2, input$cp3, input$cp4),
      season = c(input$season1, input$season2, input$season3, input$season4)
    )

    result <- tryCatch({
      lapply(1:4, function(i) {
        prepare_forecast(
          data            = dataset(),
          holidays_df     = final_holidays(),
          cp              = prior_grid$cp[i],
          season          = prior_grid$season[i],
          holiday         = input$holiday,
          horizon         = convert_months_to_horizon(input$horizon_months, input$date_agg),
          exclude_sundays = input$sundays,
          yearly          = input$add_yearly,
          weekly          = input$add_weekly,
          daily           = input$add_daily
        )
      })
    }, error = function(e) {
      showNotification(paste("❌ Trend comparison failed:", e$message), type = "error")
      NULL
    })

    comparison_data(if (is.null(result)) NULL else list(prior_grid = prior_grid, results = result))
  })

  output$comparisonPlot <- renderPlot({
    validate(need(comparison_data(), "Generate a combined trend plot to see results here."))
    cd <- comparison_data()

    trend_lines <- lapply(seq_along(cd$results), function(i) {
      cd$results[[i]]$forecast |>
        select(ds, yhat) |>
        mutate(model = paste("CP:", cd$prior_grid$cp[i], "| Season:", cd$prior_grid$season[i]))
    })
    comparison_df <- bind_rows(trend_lines)

    ggplot(comparison_df, aes(x = ds, y = yhat, color = model)) +
      geom_line(linewidth = 1.2, alpha = 0.5) +
      labs(title = "Trend Comparison Across Prior Settings", y = "Predicted Value", x = "Date") +
      theme_minimal(base_family = "serif") +
      theme(legend.position = "top", legend.title = element_blank())
  })

  output$comparisonMetrics <- renderTable({
    validate(need(comparison_data(), "Generate a combined trend plot to see results here."))
    cd <- comparison_data()

    metrics_list <- lapply(seq_along(cd$results), function(i) {
      safe_compute_metrics(cd$results[[i]]$forecast, cd$results[[i]]$train, label = cd$prior_grid$Label[i])
    })

    bind_rows(metrics_list) %>%
      tidyr::pivot_wider(names_from = Set, values_from = Value) %>%
      dplyr::select(Metric, A, B, C, D)
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