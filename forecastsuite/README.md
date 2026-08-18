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
- Population normalization: divide by a population table to forecast incidence (e.g.
  cases per 100,000) rather than absolute counts.
- A full holiday system: Sundays, a fixed-date catalog, movable holidays from a file,
  manual entries, relabel/remove, per-holiday windows, and a consistency check against
  your data.
- Multi-window evaluation (Train / Last 6 Months / Last 2 Years / held-out Test) and
  suggested starting hyperparameters (including ARIMA/SARIMA's p, d, q, P, D, Q, all
  data-derived) alongside the model recommendation.
- Individual Observations as an alternative to Aggregated data: import one row per
  event (e.g. one case, one visit) and it's counted into periods for you, no value
  column needed. Population normalization works with either format.
- A Model Guide tab explaining every model, the parameters, the metrics, and how the
  recommendation heuristic works.
- A "Show Code" panel that prints runnable R reproducing whatever you just fit or
  compared, downloadable as a `.R` file.
- Plot appearance controls (trend/uncertainty/holiday/changepoint toggles, colour
  pickers for every line) and one-click downloads: the processed dataset and the
  holiday list as CSV, and the forecast plot -- single-model or the multi-model
  comparison -- as PNG.
- A bundled 5-year demo dataset (simulated daily clinic visits, with missing and
  partially-open Sundays) so you can explore the whole app with no data of your own --
  pick it from the same icon row as the other import sources.

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
