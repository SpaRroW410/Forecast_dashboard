# model_guide_tab.R
tabPanel("📘 Model Guide",
                            fluidPage(
                              h2("📘 Prophet Forecasting Model Guide"),
                              tags$hr(),
                              
                              tags$details(open = TRUE,
                                           tags$summary("📖 What is Prophet?"),
                                           p("Prophet is an open-source forecasting tool developed by Facebook (now Meta) designed for time series data with strong seasonal patterns and trend shifts."),
                                           p("It is based on an additive model where non-linear trends are fit with yearly, weekly, and daily seasonality, plus holiday effects."),
                                           p("Prophet is robust to missing data, outliers, and trend changes, making it ideal for business forecasting tasks."),
                                           tags$p("🔗 Learn more from these trusted sources:"),
                                           tags$ul(
                                             tags$li(a(href = "https://facebook.github.io/prophet/", target = "_blank", "Official Prophet Documentation")),
                                             tags$li(a(href = "https://www.geeksforgeeks.org/time-series-analysis-using-facebook-prophet/", target = "_blank", "GeeksforGeeks: Time Series Analysis with Prophet")),
                                             tags$li(a(href = "https://machinelearningmastery.com/time-series-forecasting-with-prophet-in-python/", target = "_blank", "Machine Learning Mastery: Forecasting with Prophet"))
                                           )
                              ),
                              
                              tags$details(open = FALSE,
                                           tags$summary("🎯 Model Parameters"),
                                           tags$ul(
                                             tags$li(strong("Changepoint Prior Scale:"), " Controls the flexibility of the trend. Higher values allow more abrupt changes."),
                                             tags$li(strong("Seasonality Prior Scale:"), " Controls the flexibility of seasonal components. Higher values allow more variation."),
                                             tags$li(strong("Holiday Prior Scale:"), " Controls the strength of holiday effects. Higher values allow larger holiday impacts.")
                                           )
                              ),
                              
                              tags$details(open = FALSE,
                                           tags$summary("📆 Holidays & Exceptions"),
                                           p("Prophet allows you to define custom holidays and special events."),
                                           tags$ul(
                                             tags$li("You can assign upper and lower windows to extend the effect of a holiday."),
                                             tags$li("If two holidays fall on the same day, Prophet will sum their effects."),
                                             tags$li("Holiday effects are modeled as additive components.")
                                           )
                              ),
                              
                              tags$details(open = FALSE,
                                           tags$summary("🔁 Seasonality Components"),
                                           tags$ul(
                                             tags$li(strong("Yearly Seasonality:"), " Captures annual patterns (e.g., flu season, festivals)."),
                                             tags$li(strong("Weekly Seasonality:"), " Captures weekly cycles (e.g., weekend dips)."),
                                             tags$li(strong("Daily Seasonality:"), " Useful for hourly data."),
                                             tags$li(strong("Custom Seasonality:"), " You can define your own seasonal cycles (e.g., quarterly).")
                                           )
                              ),
                              
                              tags$details(open = FALSE,
                                           tags$summary("📊 Evaluation Metrics"),
                                           tags$ul(
                                             tags$li(strong("MASE:"), " Scale-independent. Values < 1 indicate better than naive forecast."),
                                             tags$li(strong("sMAPE:"), " Symmetric Mean Absolute Percentage Error. Less sensitive to outliers."),
                                             tags$li(strong("RMSE:"), " Root Mean Squared Error. Penalizes large errors more heavily.")
                                           )
                              ),
                              tags$details(open = FALSE,
                                           tags$summary("🧪 Interactive Parameter Demo"),
                                           checkboxInput("enable_demo", "Enable Interactive Demo", value = FALSE),
                                           
                                           conditionalPanel(
                                             condition = "input.enable_demo == false",
                                             div(
                                               style = "padding: 20px; background-color: #fdf6e3; border: 1px solid #ccc; border-radius: 5px;",
                                               h4("⚠️ Demo Disabled"),
                                               p("Enable the toggle above to explore how Prophet parameters affect forecasts."),
                                               p("This demo is memory-intensive and is off by default to keep the app responsive.")
                                             )
                                           ),
                                           
                                           conditionalPanel(
                                             condition = "input.enable_demo == true",
                                             fluidRow(
                                               column(6,
                                                      sliderInput("demo_cp", "Changepoint Prior Scale", min = 0.001, max = 0.5, value = 0.05, step = 0.01),
                                                      sliderInput("demo_season", "Seasonality Prior Scale", min = 1, max = 20, value = 10, step = 1)
                                               ),
                                               column(6,
                                                      checkboxInput("demo_show_trend", "Show Trend Line", TRUE),
                                                      checkboxInput("demo_show_uncertainty", "Show Uncertainty Interval", TRUE)
                                               )
                                             ),
                                             shinycssloaders::withSpinner(plotOutput("demoPlot"), type = 6)
                                           )
                              )
                            )
)