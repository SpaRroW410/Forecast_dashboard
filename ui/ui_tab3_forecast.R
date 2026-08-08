tabPanel(
  title = "Forecast & Evaluation",
  value = "forecast_tab",
  sidebarLayout(
    sidebarPanel(
      width = 4,
      
      # 🔧 Model Parameters
      tags$details(open = TRUE,
                   tags$summary("🔧 Model Parameters"),
                   sliderInput("cp", "Changepoint Prior Scale", min = 0.01, max = 0.5, value = 0.05, step = 0.01),
                   sliderInput("season", "Seasonality Prior Scale", min = 1, max = 20, value = 10, step = 1),
                   sliderInput("holiday", "Holiday Prior Scale", min = 0.1, max = 10, value = 5, step = 0.1),
                   sliderInput("horizon_months", "Forecast Horizon (months)", min = 1, max = 60, value = 24),
                   checkboxInput("sundays", "Exclude Sundays in Forecasting", TRUE)
      ),
      
      # 📆 Seasonality Components
      tags$details(open = TRUE,
                   tags$summary("📆 Seasonality Components"),
                   checkboxInput("add_yearly", "Include Yearly Seasonality", TRUE),
                   checkboxInput("add_weekly", "Include Weekly Seasonality", TRUE),
                   checkboxInput("add_daily", "Include Daily Seasonality", FALSE)
      ),
      
      # 📊 Plot Options
      tags$details(open = TRUE,
                   tags$summary("📊 Plot Appearance"),
                   checkboxInput("show_trend", "Show Trend Line", TRUE),
                   checkboxInput("show_uncertainty", "Show Uncertainty Interval", TRUE),
                   checkboxInput("show_holidays", "Mark Holidays", FALSE),
                   checkboxInput("show_changepoints", "Mark Changepoints", FALSE),
                   colourpicker::colourInput("trend_color", "Trend Line", "#1b9e77"),
                   colourpicker::colourInput("uncertainty_color", "Uncertainty Ribbon", "#1b9e77"),
                   colourpicker::colourInput("holiday_color", "Holiday Lines", "#d95f02"),
                   colourpicker::colourInput("changepoint_color", "Changepoint Lines", "#7570b3")
      ),
      
      hr(),
      actionButton("forecast_btn", "🚀 Generate Forecast", width = "100%"),
      
      # 🧪 Evaluation
      tags$details(open = TRUE,
                   tags$summary("🧪 Evaluation Settings"),
                   sliderInput("manual_test_months", "Manual Test Window (months)", min = 1, max = 60, value = 12)
      ),
      actionButton("eval_btn", "📋 Generate Evaluation Metrics", width = "100%"),
      
      # 📊 Trend Comparison
      tags$details(open = TRUE,
                   tags$summary("📊 Trend Comparison Across Priors"),
                   fluidRow(
                     column(6, numericInput("cp1", "CP A", value = 0.01),
                            numericInput("season1", "Season A", value = 1)),
                     column(6, numericInput("cp2", "CP B", value = 0.5),
                            numericInput("season2", "Season B", value = 20))
                   ),
                   fluidRow(
                     column(6, numericInput("cp3", "CP C", value = 0.1),
                            numericInput("season3", "Season C", value = 5)),
                     column(6, numericInput("cp4", "CP D", value = 0.2),
                            numericInput("season4", "Season D", value = 15))
                   ),
                   actionButton("comparison_btn", "📊 Generate Combined Trend Plot", width = "100%")
      ),
      
      # 📈 Plotly Forecast
      tags$details(open = FALSE,
                   tags$summary("📈 Interactive Forecast (Plotly)"),
                   checkboxInput("enable_plotly", "Enable Interactive Forecast (uses more memory)", value = FALSE),
                   conditionalPanel(
                     condition = "input.enable_plotly == true",
                     actionButton("plotly_btn", "📈 Generate Interactive Forecast", width = "100%")
                   )
      )
    ),
    
    mainPanel(
      h4("📈 Forecast Plot"),
      shinycssloaders::withSpinner(plotOutput("forecastPlot"), type = 6),
      downloadButton("downloadPlot", "📥 Download Forecast Plot"),
      hr(),
      
      h4("📋 Evaluation Metrics Summary"),
      shinycssloaders::withSpinner(DTOutput("metricsTable"), type = 6),
      hr(),

      h4("📊 Trend Comparison of Model Priors"),
      shinycssloaders::withSpinner(plotOutput("comparisonPlot"), type = 6),
      h4("📋 Metrics for Prior Combinations (A–D)"),
      shinycssloaders::withSpinner(tableOutput("comparisonMetrics"), type = 6),
      hr(),

      conditionalPanel(
        condition = "input.enable_plotly == true",
        h4("📈 Interactive Forecast (Plotly)"),
        shinycssloaders::withSpinner(plotlyOutput("plotlyForecast"), type = 6)
      )
    )
  )
)