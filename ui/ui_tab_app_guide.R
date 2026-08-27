# ui_tab_app_guide.R -- the end-to-end flow of making a forecast in this
# app, as opposed to the Model Guide's per-model/per-parameter reference.
tabPanel("🧭 Application Guide",
         fluidPage(
           h2("🧭 Application Guide"),
           p("The flow of making a forecast in this app, start to finish. See the Model Guide tab for what each model/parameter/metric actually means."),
           tags$hr(),

           tags$details(open = TRUE,
                        tags$summary("Step 1: Import your data (Data Import tab)"),
                        tags$ul(
                          tags$li("Upload a file, or pull a data frame from your R global environment / a Google Sheet / a CSV URL / pasted text."),
                          tags$li("Pick your date and value columns, whether rows are Aggregated or Individual Observations, and the aggregation frequency."),
                          tags$li("Once processed, the Holiday, Forecast, ARIMA, and SARIMA tabs become available.")
                        )
           ),

           tags$details(open = FALSE,
                        tags$summary("Step 2: Configure holidays (Holiday Settings tab, optional)"),
                        tags$ul(
                          tags$li("Skip this entirely if your data has no calendar-driven effects -- every model works without it."),
                          tags$li("Otherwise import movable holidays from a file (download the example file on that tab first if you're unsure of the format), add fixed/manual entries, and finalize."),
                          tags$li("The Contingency Check sub-tab can help catch dates that look like closures but were never declared.")
                        )
           ),

           tags$details(open = FALSE,
                        tags$summary("Step 3: Pick a model and fit"),
                        tags$ul(
                          tags$li(strong("Forecast & Evaluation (Prophet): "), "set changepoint/seasonality/holiday priors, seasonality components, and a forecast horizon, then Generate Forecast."),
                          tags$li(strong("ARIMA: "), "a non-seasonal, auto-selected order fit -- one click."),
                          tags$li(strong("SARIMA: "), "the seasonal counterpart to ARIMA, also auto-selected -- one click.")
                        )
           ),

           tags$details(open = FALSE,
                        tags$summary("Step 4: Read your results"),
                        p("Each model tab shows a forecast plot and some essential statistics -- Prophet also has an evaluation metrics table (MASE/sMAPE/RMSE) and a downloadable plot; ARIMA/SARIMA show ", code("summary(model)"), " (AIC, coefficients, residual variance).")
           ),

           tags$details(open = FALSE,
                        tags$summary("Want more? Install the forecastsuite R package"),
                        p("This hosted app deliberately stays lightweight (Prophet, ARIMA, SARIMA -- essential functions only) to fit a free ~1GB-RAM hosting tier. ",
                          code("forecastsuite"), " is a separate local R package with the same workflow, no memory constraints, and a lot more: SARIMA with manual order entry, ETS, TBATS, NNETAR, Holt-Winters, optional LSTM, an N-way model comparison, cross-validation, grouping/hierarchical reconciliation, an Analysis panel (seasonal decomposition, anomaly detection, residual diagnostics, cross-group correlation), and project save/load."),
                        tags$p(strong("Install it (pick one):")),
                        tags$ul(
                          tags$li("Already have this repository cloned: ", code('remotes::install_local("forecastsuite")')),
                          tags$li("From anywhere: ", code('remotes::install_github("SpaRroW410/Forecast_dashboard", subdir = "forecastsuite")'))
                        ),
                        tags$p(strong("Then run it: "), code("forecastsuite::run_app()")),
                        p("See ", a(href = "https://github.com/SpaRroW410/Forecast_dashboard/tree/main/forecastsuite", target = "_blank", "the forecastsuite/ folder in this repository"), " for its own README and a vignette (", code('vignette("forecastsuite")'), ") covering both the app and its registry API for scripting forecasts directly in R.")
           )
         )
)
