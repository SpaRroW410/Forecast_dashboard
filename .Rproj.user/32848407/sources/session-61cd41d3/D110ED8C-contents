tabPanel("Forecast & Evaluation",
         
         sidebarLayout(
           sidebarPanel(
             width = 4,
             
             tags$details(open = TRUE,
                          tags$summary("🔧 Model Parameters"),
                          sliderInput("cp", "Changepoint Prior Scale", min = 0.01, max = 0.5, value = 0.05, step = 0.01),
                          sliderInput("season", "Seasonality Prior Scale", min = 1, max = 20, value = 10, step = 1),
                          sliderInput("holiday", "Holiday Prior Scale", min = 0.1, max = 10, value = 5, step = 0.1),
                          sliderInput("horizon_months", "Forecast Horizon (months)", min = 1, max = 60, value = 24),
                          checkboxInput("sundays", "Exclude Sundays in Forecasting", TRUE)
             ),
             
             tags$details(open = TRUE,
                          tags$summary("📆 Seasonality Components"),
                          checkboxInput("add_yearly", "Include Yearly Seasonality", TRUE),
                          checkboxInput("add_weekly", "Include Weekly Seasonality", TRUE),
                          checkboxInput("add_daily", "Include Daily Seasonality", FALSE)
             ),
             tags$details(open = TRUE,
                          tags$summary("🧪 Evaluation Settings"),
                          sliderInput("manual_test_months", "Manual Test Window (months)", min = 1, max = 60, value = 12)
             ),
             
             tags$details(open = TRUE,
                          tags$summary("📊 Plot Options"),
                          checkboxInput("show_trend", "Show Trend Line", TRUE),
                          checkboxInput("show_uncertainty", "Show Uncertainty Interval", TRUE),
                          checkboxInput("show_holidays", "Mark Holidays", FALSE),
                          checkboxInput("show_changepoints", "Mark Changepoints", FALSE)
             ),
             
             tags$details(open = FALSE,
                          tags$summary("🎨 Customize Colors"),
                          colourpicker::colourInput("trend_color", "Trend Line", "#1b9e77"),
                          colourpicker::colourInput("uncertainty_color", "Uncertainty Ribbon", "#1b9e77"),
                          colourpicker::colourInput("holiday_color", "Holiday Lines", "#d95f02"),
                          colourpicker::colourInput("changepoint_color", "Changepoint Lines", "#7570b3")
             ),
             
             hr(),
             actionButton("forecast_btn", "🚀 Generate Forecast", width = "100%"),
             tags$details(open = FALSE,
                          tags$summary("🧪 Comparison Settings"),
                          h5("Select 4 Prior Combinations"),
                          fluidRow(
                            column(6,
                                   numericInput("cp1", "CP 1", value = 0.01, min = 0.001, max = 1, step = 0.01),
                                   numericInput("cp2", "CP 2", value = 0.5, min = 0.001, max = 1, step = 0.01)
                            ),
                            column(6,
                                   numericInput("season1", "Season 1", value = 1, min = 0.1, max = 50, step = 0.1),
                                   numericInput("season2", "Season 2", value = 20, min = 0.1, max = 50, step = 0.1)
                            )
                          )
             )
           ),
           
           mainPanel(
             h4("📈 Forecast Plot"),
             shinycssloaders::withSpinner(plotOutput("forecastPlot"), type = 6),
             downloadButton("downloadPlot", "📥 Download Forecast Plot"),
             hr(),
             h4("📊 Evaluation Metrics"),
             tableOutput("metricsTable"),
             hr(),
             h4("📊 Visual Summary of Metrics"),
             shinycssloaders::withSpinner(plotOutput("metricsPlot"), type = 6),
             
             hr(),
             h4("🌀 Seasonality & Holiday Effects"),
             shinycssloaders::withSpinner(plotOutput("seasonalityPlot"), type = 6),
             hr(),
             h4("📊 Visual Comparison of Model Priors"),
             shinycssloaders::withSpinner(plotOutput("comparisonPlot"), type = 6),
             hr(),
             h4("📈 Interactive Forecast (Plotly)"),
             tags$p("⚠️ This plot may render slowly or behave inconsistently on low-spec systems or with long time series."),
             shinycssloaders::withSpinner(plotlyOutput("plotlyForecast"), type = 6)
           
             )
         )
)
