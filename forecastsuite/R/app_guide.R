# Model Guide tab for the bundled app. Adapted from the hosted app's
# ui/model_guides.R (same collapsible tags$details structure), extended to
# cover every model in the registry rather than Prophet alone.

build_guide_tab_ui <- function() {
  shiny::fluidPage(
    shiny::h2("Model Guide"),
    shiny::tags$hr(),

    shiny::tags$details(
      open = TRUE,
      shiny::tags$summary("Uploading Your Data"),
      shiny::tags$ul(
        shiny::tags$li(shiny::strong("Import sources: "),
                       "upload a CSV, pick a data frame already in your R global environment, fetch a CSV from a URL, or paste delimited text directly."),
        shiny::tags$li(shiny::strong("Date / Value columns: "),
                       "pick which uploaded columns hold the timestamp and the metric to forecast. They are renamed internally to ds and y."),
        shiny::tags$li(shiny::strong("Aggregation frequency: "),
                       "Hourly / Daily / Weekly / Monthly. This should match how often you actually have observations; choosing a frequency finer than your real data granularity will error."),
        shiny::tags$li(shiny::strong("Common pitfalls: "),
                       "very short series cannot support seasonality detection; re-importing a new dataset resets the column pickers, so re-select them before finalizing.")
      )
    ),

    shiny::tags$details(
      open = FALSE,
      shiny::tags$summary("How Model Recommendation Works"),
      shiny::p("After you finalize a dataset, a lightweight heuristic scores every available model and shows a ranked table with short reasons. No models are actually fit, so it is fast -- treat it as a starting suggestion, not a verdict."),
      shiny::tags$ul(
        shiny::tags$li(shiny::strong("Trend strength: "), "how much variation is explained by a smooth long-term trend (STL decomposition)."),
        shiny::tags$li(shiny::strong("Seasonality strength: "), "how much variation repeats on a regular cycle, tested against calendar-sensible candidate periods for your chosen aggregation."),
        shiny::tags$li(shiny::strong("Differencing needed: "), "how many differences an ARIMA-family model would need (forecast::ndiffs / nsdiffs)."),
        shiny::tags$li(shiny::strong("Data regularity: "), "what fraction of expected time steps are missing."),
        shiny::tags$li(shiny::strong("Holidays: "), "every model except Prophet is scored down when holidays are configured, since none of the others model holiday effects.")
      )
    ),

    shiny::tags$details(
      open = FALSE,
      shiny::tags$summary("Model Parameters"),
      shiny::tags$ul(
        shiny::tags$li(shiny::strong("Changepoint Prior Scale (Prophet): "), "trend flexibility. Higher allows more abrupt trend shifts."),
        shiny::tags$li(shiny::strong("Seasonality Prior Scale (Prophet): "), "seasonal flexibility. Higher allows larger seasonal swings."),
        shiny::tags$li(shiny::strong("Holiday Prior Scale (Prophet): "), "strength of holiday effects."),
        shiny::tags$li(shiny::strong("p, d, q (ARIMA/SARIMA): "), "autoregressive order, differencing order, moving-average order."),
        shiny::tags$li(shiny::strong("P, D, Q (SARIMA): "), "the same three orders applied at the seasonal period."),
        shiny::tags$li(shiny::strong("Forecast horizon: "), "how far ahead to predict."),
        shiny::tags$li(shiny::strong("Manual test window: "), "how much data at the end of the series is held out for evaluation. Every model is scored on this same held-out window.")
      )
    ),

    shiny::tags$details(
      open = FALSE,
      shiny::tags$summary("Evaluation Metrics"),
      shiny::tags$ul(
        shiny::tags$li(shiny::strong("MASE: "), "scale-independent. Below 1 beats a naive forecast."),
        shiny::tags$li(shiny::strong("sMAPE (%): "), "symmetric mean absolute percentage error; less outlier-sensitive than MAPE."),
        shiny::tags$li(shiny::strong("RMSE: "), "root mean squared error; penalizes large misses more heavily.")
      )
    ),

    shiny::tags$details(
      open = FALSE,
      shiny::tags$summary("The Models"),
      shiny::tags$details(
        open = FALSE, shiny::tags$summary("Prophet"),
        shiny::p("Additive model with non-linear trend plus yearly/weekly/daily seasonality and holiday effects. Robust to missing data, outliers and trend shifts. The only model here that uses holidays.")
      ),
      shiny::tags$details(
        open = FALSE, shiny::tags$summary("ARIMA"),
        shiny::p("Classical AutoRegressive Integrated Moving Average. Orders can be auto-selected (forecast::auto.arima) or entered manually as p, d, q. Strong on regular, well-behaved series. Ignores holidays.")
      ),
      shiny::tags$details(
        open = FALSE, shiny::tags$summary("SARIMA"),
        shiny::p("Seasonal ARIMA -- adds seasonal (P, D, Q) terms at the series' seasonal period on top of ARIMA's (p, d, q). Use when the series has a clear repeating cycle. The fitted order is shown on the plot, e.g. ARIMA(2,1,1)(1,0,0)[12].")
      ),
      shiny::tags$details(
        open = FALSE, shiny::tags$summary("ETS (Exponential Smoothing)"),
        shiny::p("Error/Trend/Seasonal state-space smoothing. A fast, strong general-purpose baseline for series with smooth trend and seasonality.")
      ),
      shiny::tags$details(
        open = FALSE, shiny::tags$summary("TBATS"),
        shiny::p("Handles complex or multiple seasonal patterns at once, e.g. daily data with both weekly and yearly cycles. Slower to fit than ETS or ARIMA.")
      ),
      shiny::tags$details(
        open = FALSE, shiny::tags$summary("NNETAR (Neural Net)"),
        shiny::p("Autoregressive neural network. Can capture non-linear structure given enough data, at the cost of interpretability. Prediction intervals are off by default because they require bootstrap simulation, so this model shows no uncertainty ribbon.")
      ),
      shiny::tags$details(
        open = FALSE, shiny::tags$summary("Holt-Winters"),
        shiny::p("Classic exponential smoothing with level, trend and a single seasonal component. Needs at least two full seasonal cycles; with less data it automatically falls back to a non-seasonal fit.")
      ),
      shiny::tags$details(
        open = FALSE, shiny::tags$summary("LSTM (requires torch)"),
        shiny::p("Recurrent neural network suited to larger datasets with complex temporal dependencies. Optional: install with install.packages(\"torch\") then torch::install_torch(). Until torch is installed, LSTM simply does not appear in the model selector.")
      )
    ),

    shiny::tags$details(
      open = FALSE,
      shiny::tags$summary("Holidays"),
      shiny::tags$ul(
        shiny::tags$li("Only Prophet models holiday effects. Every other model shows a note saying so."),
        shiny::tags$li("Sundays can be marked as a recurring holiday with one checkbox."),
        shiny::tags$li("Manual holidays can repeat every year in the dataset's range, or apply to a single date."),
        shiny::tags$li("Finalize holidays before fitting so Prophet picks them up.")
      )
    ),

    shiny::tags$details(
      open = FALSE,
      shiny::tags$summary("Reproducing your work in code"),
      shiny::p("The Model tab has a \"Show Code\" panel at the bottom that prints the R code equivalent to whatever you just fit or compared, using forecastsuite's registry directly. It regenerates on each Fit or Compare click and can be downloaded as a .R file, so any result in the app can be reproduced in a plain script.")
    )
  )
}
