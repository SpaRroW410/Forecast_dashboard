# forecastsuite

A local, full-featured companion to the hosted Forecast Dashboard Shiny app. Where the
hosted app deliberately sticks to Prophet + ARIMA to fit a ~1GB-RAM free hosting tier,
this package has no such constraint and adds:

- A pluggable model registry (`register_model()`/`get_model()`/`list_models()`) — every
  model implements a `fit`/`forecast`/`to_tibble` contract, so adding a new model later
  is one file + one `register_model()` call.
- Built-in models: Prophet, ARIMA, SARIMA (both with auto and manual p,d,q/P,D,Q order
  entry), ETS, TBATS, NNETAR, Holt-Winters, and LSTM (optional, requires `torch`).
- A bundled local Shiny app (`run_app()`) with all models exposed, Plotly always on, and
  a dataset-driven model recommendation step.
- Import from any of four sources: a file upload (CSV, TSV or Excel -- multi-sheet
  workbooks let you pick the worksheet), a data frame already in your R global
  environment, a link-shared Google Sheet, a CSV URL, or pasted delimited text.
- Dates split across columns (Year + Quarter, Year + Month, optionally + Day) are
  assembled automatically, and aggregation is set to the finest part supplied.
- An N-way model comparison: overlay several models' forecasts on one Plotly chart
  alongside the side-by-side metrics table.
- A Model Guide tab explaining every model, the parameters, the metrics, and how the
  recommendation heuristic works.
- A "Show Code" panel that prints runnable R reproducing whatever you just fit or
  compared, downloadable as a `.R` file.

## Install

```r
install.packages("remotes")
remotes::install_local("forecastsuite")
```

## Run the app

```r
forecastsuite::run_app()
```

## LSTM support (optional)

```r
install.packages("torch")
torch::install_torch()
```

Everything else works without `torch` — `list_models()` simply omits LSTM until it's
installed.

## Relationship to the hosted app

`R/data_utils.R`, `R/metric_utils.R`, `R/holidays_helpers.R`, and `R/horizon_utils.R` are
adapted from the parent repo's `helpers/` files (same behavior, package-namespaced). They
are intentionally **copied, not shared**, so this package and the hosted app can evolve
independently without one destabilizing the other. If you fix a bug in one copy, check
whether the other needs the same fix.
