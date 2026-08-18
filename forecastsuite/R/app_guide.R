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
                       "upload a CSV, TSV or Excel workbook (.xlsx/.xls -- multi-sheet books let you pick the worksheet), choose a data frame already in your R global environment, pull in a Google Sheet (paste its link; the sheet must be shared as \"Anyone with the link can view\", and no Google sign-in is needed), fetch a CSV from a URL, or paste delimited text directly."),
        shiny::tags$li(shiny::strong("Date / Value columns: "),
                       "pick which uploaded columns hold the timestamp and the metric to forecast. They are renamed internally to ds and y."),
        shiny::tags$li(shiny::strong("Dates split across columns: "),
                       "if the period is stored as separate Year and Quarter/Month (and optionally Day) columns rather than one date, switch \"Date is stored as\" to the split option and select those columns. Quarters accept 1-4 or Q1-Q4; months accept 1-12 or names like Jan / January. Aggregation is then set automatically to the finest part you supplied -- Year+Quarter gives quarterly, Year+Month gives monthly, Year alone gives yearly."),
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
      ),
      shiny::p(shiny::strong("Suggested settings: "),
               "the table also proposes starting hyperparameters -- Prophet changepoint and seasonality priors scaled to the measured trend and seasonal strength, and an ARIMA/SARIMA starting order whose d and D come straight from ndiffs() and nsdiffs(). These are informed starting points, not optimal values: auto-select still searches the ARIMA order space better than any heuristic, so the suggested p and q matter mainly if you intend to hand-tune. This is what replaces fitting a grid of four prior combinations just to see which one wins.")
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
      shiny::tags$summary("Comparing models"),
      shiny::p("On the Model tab, tick several models under \"Compare Models\" and click Compare. Every selected model is fit on the same training split and scored on the same held-out window, then their forecasts are overlaid on one interactive chart with a side-by-side metrics table beneath it. A model that fails to fit is skipped in the chart and shown as NA in the table, so one bad fit never blocks the rest.")
    ),

    shiny::tags$details(
      open = FALSE,
      shiny::tags$summary("Evaluation Metrics"),
      shiny::tags$ul(
        shiny::tags$li(shiny::strong("Windows: "), "each fit is scored on Train, the last 6 months and last 2 years where the series is long enough, and the held-out test window -- one number hides where a model actually fails."),
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
      shiny::p("Only Prophet models holiday effects; every other model shows a note saying so. Build the list from any combination of these sources, then Finalize before fitting."),
      shiny::tags$ul(
        shiny::tags$li(shiny::strong("Sundays: "), "generated across the year range you pick."),
        shiny::tags$li(shiny::strong("Fixed-date catalog: "), "Republic Day, Independence Day, Gandhi Jayanti, Christmas, Ambedkar Jayanti and Makar Sankranti, expanded across the same year range."),
        shiny::tags$li(shiny::strong("Movable holidays: "), "upload a table for holidays whose date shifts each year (Diwali, Eid, Easter), then map its date and label columns."),
        shiny::tags$li(shiny::strong("Manual entry: "), "either repeating every year in the range, or a single one-off date."),
        shiny::tags$li(shiny::strong("Editing: "), "select rows in the compiled table to relabel or remove them; Clear all starts over."),
        shiny::tags$li(shiny::strong("Windows: "), "give a holiday a lower/upper window so the days around it share its effect, e.g. a long weekend.")
      ),
      shiny::p(shiny::strong("Consistency check: "),
               "cross-checks the declared list against your data. \"Holidays with non-zero data\" are days you declared a holiday but which still carry values -- either the holiday was not observed there, or entry continued anyway. \"Dates always zero or missing\" are calendar dates that are empty in every year; those flagged as not already declared are de facto closures the model cannot otherwise account for.")
    ),

    shiny::tags$details(
      open = FALSE,
      shiny::tags$summary("Population normalization (incidence)"),
      shiny::p("On the Import tab, expand \"Population normalization\" to forecast incidence rather than absolute counts. Supply a population table keyed by year (or date), pick its key and population columns, and set a unit divisor -- 100000 gives cases per 100,000."),
      shiny::p("Order matters and is handled for you: rows sharing a period are summed first, and only the period total is divided by population. Normalizing each row and then adding would sum rates, which is meaningless.")
    ),

    shiny::tags$details(
      open = FALSE,
      shiny::tags$summary("Reproducing your work in code"),
      shiny::p("The Model tab has a \"Show Code\" panel at the bottom that prints the R code equivalent to whatever you just fit or compared, using forecastsuite's registry directly. It regenerates on each Fit or Compare click and can be downloaded as a .R file, so any result in the app can be reproduced in a plain script.")
    )
  )
}
