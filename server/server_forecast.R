forecast_server <- function(input, output, session, dataset, final_holidays) {
  
  # 🔹 Reactive store for main forecast results
  forecast_data <- reactiveVal(NULL)
  
  # 🔹 Generate primary forecast
  observeEvent(input$forecast_btn, {
    req(dataset(), input$date_agg)

    # Checks run in order of what the user must change first; each one stops
    # the forecast with a message rather than an error.
    # 1. Hourly data has no Prophet horizon mapping in this app (this used to
    #    throw outside the tryCatch below and end the session).
    if (!notify_unless(input$date_agg != "hour",
                       "Prophet forecasting here supports daily, weekly and monthly data. For hourly data use the ARIMA or SARIMA tab.",
                       type = "error")) return()

    df <- dataset()
    test_cutoff <- max(df$ds) %m-% months(input$manual_test_months)
    train_df <- df[df$ds <= test_cutoff, ]
    test_df  <- df[df$ds > test_cutoff, ]

    # 2. Prophet needs at least two training rows; say why instead of surfacing
    # Prophet's own "Dataframe has less than 2 non-NA rows" error (which is
    # what the bundled 1-year demo dataset hit with the 12-month default).
    if (nrow(train_df) < 2) {
      showNotification(
        sprintf(
          "❌ The hold-out test period (%s months) covers all of your data (%s to %s), leaving nothing to train on. Make the hold-out test period shorter and generate the forecast again.",
          input$manual_test_months, format(as.Date(min(df$ds))), format(as.Date(max(df$ds)))
        ),
        type = "error", duration = NULL
      )
      return()
    }

    # 3. Holidays are optional: no list in use (NULL) or an empty one means
    #    "forecast without holidays". Said only once the forecast will run.
    holidays_df <- final_holidays()
    if (!is.null(holidays_df) && nrow(holidays_df) == 0) holidays_df <- NULL
    if (is.null(holidays_df)) {
      showNotification("ℹ️ No holiday list has been finalized, so this forecast runs without holiday effects.",
                       type = "message", duration = 6)
    }

    horizon_periods <- convert_months_to_horizon(input$horizon_months, input$date_agg)

    app_log(sprintf("forecast started: %d training rows, horizon %d %s periods, %s",
                    nrow(train_df), horizon_periods, input$date_agg,
                    if (is.null(holidays_df)) "no holidays" else sprintf("%d holiday dates", nrow(holidays_df))),
            session = session)
    t0 <- Sys.time()
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
      app_log("ERROR forecast failed after ", seconds_since(t0), " s: ", conditionMessage(e), session = session)
      showNotification(paste("❌ Forecast failed:", e$message), type = "error")
      NULL
    })
    if (!is.null(result)) app_log("forecast fitted in ", seconds_since(t0), " s", session = session)

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
    if (!notify_unless(!is.null(forecast_data()), "📋 Generate a forecast first (🚀 Generate Forecast), then the metrics.")) return()
    f <- forecast_data()
    
    output$metricsTable <- DT::renderDT({
      req(forecast_data())
      f <- forecast_data()
      
      # ⏳ Compute metrics across subsets
      metrics <- bind_rows(
        safe_compute_metrics(f$forecast, f$train, "Train"),
        safe_compute_metrics(f$forecast, f$train[f$train$ds > (max(f$train$ds) %m-% months(6)), ], "Last 6 Months"),
        safe_compute_metrics(f$forecast, f$train[f$train$ds > (max(f$train$ds) %m-% years(2)), ], "Last 2 Years"),
        safe_compute_metrics(f$forecast, f$test, "Hold-out test")
      )
      
      # 🧮 Pivot long → wide
      metrics_wide <- tidyr::pivot_wider(
        metrics,
        names_from = Set,
        values_from = Value
      ) %>% 
        dplyr::select(Metric, `Train`, `Last 6 Months`, `Last 2 Years`, `Hold-out test`)
      
      DT::datatable(metrics_wide, options = list(dom = 't', scrollX = TRUE))
    })
  })
  # 📈 Plotly Interactive Forecast
  observeEvent(input$plotly_btn, {
    req(input$enable_plotly)
    if (!notify_unless(!is.null(forecast_data()), "📈 Generate a forecast first (🚀 Generate Forecast), then the interactive version.")) return()
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