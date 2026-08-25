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
  environment (or, esquisse-style, a built-in dataset from any installed package --
  e.g. `datasets`, `ggplot2` -- picked by package then dataset name, no `library()` or
  `data()` call needed first), a link-shared Google Sheet, a CSV URL, or pasted
  delimited text.
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
  compared, syntax-highlighted, downloadable as a `.R` file, or copyable to the
  clipboard in one click.
- An Analysis panel (Model tab): seasonal decomposition (trend/seasonal/remainder),
  anomaly detection on the raw series (IQR or z-score, downloadable as CSV), residual
  diagnostics after a fit (Ljung-Box, Shapiro-Wilk, residual ACF -- is the error
  actually unpredictable noise, or is there structure left over?), and, with a
  grouping column active, a cross-group correlation heatmap/table. Decomposition and
  anomaly detection need only a finalized dataset, no fit required.
- Plot appearance controls (trend/uncertainty/holiday/changepoint toggles, colour
  pickers for every line) and one-click downloads: the processed dataset and the
  holiday list as CSV, and the forecast plot -- single-model or the multi-model
  comparison -- as PNG.
- A bundled 5-year demo dataset (simulated daily clinic visits, with missing and
  partially-open Sundays) so you can explore the whole app with no data of your own --
  pick it from the same icon row as the other import sources.
- An optional grouping column (District, Sex, Product, ...): split your dataset into
  one time series per distinct value instead of only ever seeing the aggregate, fit
  one model across every included group, browse each group's own plot/metrics, and
  compare them on one overlay plot (actuals + forecasts, one color per group).
  Population normalization, the recommendation table, and the holiday consistency
  check are all group-aware when it's on. Messy raw values ("female"/"Female"/
  "FEMALE") are auto-merged by casing/spacing, plus a manual relabel table for
  anything else (abbreviations, typos) -- the same select-and-relabel pattern used
  for holidays.
- Bottom-up hierarchical reconciliation: once you've fit two or more groups, view a
  "Reconciled (bottom-up)" forecast -- the sum of the already-fit group forecasts,
  always coherent by construction, labeled as partial if not every configured group
  was fit this run.
- Rolling-origin cross-validation: refit the currently-viewed series at several
  walk-forward cutoffs instead of relying on one train/test split, for a more robust
  read on accuracy (Model tab, "Run Cross-Validation").
- Save your dataset(s), holidays, and every setting as one project file, and reload
  it in a fresh session with no re-import needed -- fitted results aren't saved, so
  you re-click Fit & Forecast after loading.

## Install

```r
install.packages("remotes")
remotes::install_local("forecastsuite")
```

## Run the app

```r
forecastsuite::run_app()
```

## Learn more

`vignette("forecastsuite")` walks through the bundled app tab-by-tab and the model
registry API for scripting forecasts directly in R, without the app.

## LSTM support (optional)

```r
install.packages("torch")
torch::install_torch()
```

Everything else works without `torch` — `list_models()` simply omits LSTM until it's
installed. Once available, its epochs / hidden units / lookback window / learning rate
are exposed on the Model tab like any other model's parameters, saved/restored with a
project file, and included in the "Show Code" panel.

## Relationship to the hosted app

`R/data_utils.R`, `R/metric_utils.R`, `R/holidays_helpers.R`, and `R/horizon_utils.R` are
adapted from the parent repo's `helpers/` files (same behavior, package-namespaced). They
are intentionally **copied, not shared**, so this package and the hosted app can evolve
independently without one destabilizing the other. If you fix a bug in one copy, check
whether the other needs the same fix.
