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
                                           tags$summary("📤 Uploading Your Data"),
                                           tags$ul(
                                             tags$li(strong("Date Column / Value Column:"), " pick which uploaded columns represent the timestamp and the metric you want to forecast."),
                                             tags$li(strong("Aggregation Frequency:"), " Hourly/Daily/Weekly/Monthly — how your data should be bucketed. This should roughly match how often you actually have observations; picking a frequency finer than your real data granularity will trigger an error."),
                                             tags$li(strong("Aggregated vs. Individual Observations:"), " use \"Aggregated\" if each row is already one value per time period; use \"Individual Observations\" if each row is a single event (e.g. one case per row) that should be counted per period."),
                                             tags$li(strong("Population Normalization (optional):"), " divides your values by a population figure (scaled by a multiplier/divisor) so trends are comparable across time periods with different population sizes."),
                                             tags$li(strong("Common pitfalls:"), " re-uploading a new dataset resets the column pickers — re-select them before transforming; very short datasets (a handful of rows) won't have enough history to detect seasonality reliably.")
                                           )
                              ),

                              tags$details(open = FALSE,
                                           tags$summary("🧭 How Model Recommendation Works"),
                                           p("After you finalize a dataset (Data Import tab, step 3), a lightweight heuristic — no models are actually fit — scores candidate models and shows a ranked table with short reasons. It is a starting suggestion, not a guarantee."),
                                           tags$ul(
                                             tags$li(strong("Trend strength:"), " how much of the series' variation is explained by a smooth long-term trend (via STL decomposition)."),
                                             tags$li(strong("Seasonality strength:"), " how much variation repeats on a regular cycle (e.g. weekly or yearly), checked against a few calendar-sensible candidate periods."),
                                             tags$li(strong("Stationarity / differencing needed:"), " how many differences (`forecast::ndiffs`/`nsdiffs`) a classical ARIMA-family model would need to make the series stable enough to fit."),
                                             tags$li(strong("Data regularity:"), " what fraction of expected time steps are missing."),
                                             tags$li(strong("Holidays:"), " models that can't use holiday effects (everything except Prophet) are scored down when holidays are configured — since holidays are set up on a later tab, the recommendation shown right after finalizing doesn't yet reflect them.")
                                           ),
                                           p("Prophet tends to score higher with strong seasonality, missing/irregular data, or configured holidays; ARIMA-family and other classical models tend to score higher on clean, regular, well-behaved series.")
                              ),

                              tags$details(open = FALSE,
                                           tags$summary("📈 Other Models"),
                                           p("This hosted app deliberately supports only Prophet and ARIMA to stay within a small memory budget (it targets a free ~1GB-RAM Shiny Server tier). A separate local R package, ",
                                             code("forecastsuite"), ", extends the same workflow with more models and no memory constraints — see ",
                                             a(href = "https://github.com/SpaRroW410/Forecast_dashboard/tree/main/forecastsuite", target = "_blank", "the forecastsuite/ folder in this repository"),
                                             ". Install locally with ", code('remotes::install_local("forecastsuite")'), " then run ", code("forecastsuite::run_app()"), "."),
                                           tags$details(open = FALSE,
                                                        tags$summary("ARIMA (available here)"),
                                                        p("Classical AutoRegressive Integrated Moving Average model. Fit automatically via ", code("forecast::auto.arima()"), ". Good for regular, non-seasonal or simply-seasonal data; does not model holiday effects.")
                                           ),
                                           tags$details(open = FALSE,
                                                        tags$summary("SARIMA (forecastsuite only)"),
                                                        p("Seasonal ARIMA — adds explicit seasonal (P,D,Q)[m] terms on top of ARIMA's (p,d,q). forecastsuite offers both auto-selected and manually-entered orders, and shows the fitted order (e.g. \"ARIMA(2,1,1)(1,0,0)[12]\") on the plot.")
                                           ),
                                           tags$details(open = FALSE,
                                                        tags$summary("ETS (forecastsuite only)"),
                                                        p("Exponential smoothing (Error/Trend/Seasonal). A strong, fast general-purpose baseline for short-to-medium series with smooth trend/seasonality.")
                                           ),
                                           tags$details(open = FALSE,
                                                        tags$summary("TBATS (forecastsuite only)"),
                                                        p("Handles complex or multiple seasonal patterns (e.g. daily data with both weekly and yearly cycles) that simpler models can't represent at once.")
                                           ),
                                           tags$details(open = FALSE,
                                                        tags$summary("NNETAR (forecastsuite only)"),
                                                        p("An autoregressive neural network. Can capture non-linear patterns given enough data; less interpretable than the classical methods.")
                                           ),
                                           tags$details(open = FALSE,
                                                        tags$summary("Holt-Winters (forecastsuite only)"),
                                                        p("A classic exponential-smoothing method for series with a clear trend and a single seasonal cycle.")
                                           ),
                                           tags$details(open = FALSE,
                                                        tags$summary("LSTM (forecastsuite only, requires torch)"),
                                                        p("A recurrent neural network well suited to larger datasets with complex temporal dependencies. Requires installing the ", code("torch"), " R package locally (", code("install.packages(\"torch\"); torch::install_torch()"), ") — it is optional and the rest of forecastsuite works without it.")
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