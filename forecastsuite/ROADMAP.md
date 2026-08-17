# 🔮 forecastsuite Roadmap

Forward-looking items specific to the local package (the hosted app's roadmap lives in
`../ROADMAP_v0.7.md` at the repo root).

---

## 🧑‍💻 Show-the-code panel (esquisse-style)

- [x] Collapsible panel at the bottom of the Model tab (`R/app_ui.R`) displaying the R
      code equivalent of whatever was just fit/forecast/plotted — `R/code_gen.R`'s
      `build_fit_code()`/`build_comparison_code()`, generated from the registry's
      `fit`/`forecast`/`to_tibble` calls rather than a plot spec (esquisse builds
      ggplot2 code from a plot spec; we don't have one, so we generate from the actual
      registry calls that ran instead — same spirit, different source of truth).
- [x] Regenerates on each "Fit & Forecast" / "Compare Selected Models" click, not on
      every slider tweak — shows the code that *was* run.
- [x] `train_df`/`test_df`/`holidays_df` are referenced as bare variable names rather
      than deparsed inline (would be unreadable for a whole data.frame); every other
      argument is deparsed from actual UI state via `deparse()`.
- [x] Covers both the single-model fit path and the N-way comparison path.
- [x] Verified the generated code is genuinely standalone and runnable — installed the
      package for real (`R CMD INSTALL`) and `eval()`'d generated snippets against
      fresh `train_df`/`test_df`/`holidays_df` variables with nothing else in scope.
- [ ] Still open: syntax highlighting (currently a plain `verbatimTextOutput`) and a
      "Copy to clipboard" button (`shinyjs::runjs` clipboard write, or `rclipboard`) —
      `Download as .R` shipped instead as the first, dependency-free way to get the
      code out of the app.

## 📈 Plotting & comparison parity with the hosted app

- [x] `model_shared.R::.forecast_pkg_to_tibble()` now surfaces `yhat_lower`/`yhat_upper`
      from `forecast::forecast()`'s `$lower`/`$upper` (first/narrowest interval level,
      e.g. 80%) for ARIMA/SARIMA/ETS/TBATS/Holt-Winters, giving them the same
      uncertainty ribbon Prophet already had in `plot_forecast_generic()`. NNETAR is a
      documented exception: `forecast.nnetar()` only computes intervals when
      `PI = TRUE` (bootstrapped, off by default for responsiveness), so it has no
      interval columns — not a bug, see `model_nnetar.R`'s comment.
- [x] Combined multi-model trend plot for "Compare Selected Models"
      (`plot_model_comparison()`), overlaying every selected model's forecast on one
      Plotly chart above the metrics table. Generalizes the hosted app's 4-prior
      "Combined Trend Comparison" to N registered models. A model that fails to fit
      is skipped in the plot and reported as NA in the table rather than breaking
      the comparison.

## 🧪 Verification still needed locally (see model_lstm.R and README)

- [ ] Install `torch` and confirm the LSTM adapter actually trains/forecasts —
      written and statically reviewed only so far; this sandbox has no CRAN access.
- [x] `R CMD INSTALL` end-to-end — confirmed working in this sandbox (fixed a real bug
      along the way: `DESCRIPTION`'s `Authors@R` needs a valid maintainer email or
      installation fails outright). `devtools`/`rcmdcheck`-based `R CMD check` is still
      unverified since those packages aren't installable here (no CRAN access).
- [ ] Launch `run_app()` in a real browser and click through every tab — `shiny::testServer`
      exercised the server logic headlessly this session (including the new code panel,
      via real `library(forecastsuite)` after installing it), but nothing has been
      rendered in an actual browser yet.

## 🛠 Package hygiene

- [ ] Add real `@export`/`@param` roxygen2 comments and run `roxygen2::roxygenise()`
      locally to regenerate `NAMESPACE`/`man/*.Rd` from them (currently hand-written).
- [ ] GitHub Actions CI running `R CMD check` across a couple of R versions.
- [ ] A short vignette walking through `run_app()` and the registry API for
      programmatic (non-Shiny) use.

## 📥 Import UX

- [x] Multi-source import implemented natively (no `datamods` dependency): file upload,
      a data frame already in the user's global environment, a CSV URL, and pasted
      delimited text. Implemented directly rather than via `datamods` because
      `datamods` cannot be installed or tested in the authoring sandbox, and shipping
      an unverified dependency is what caused the drawn-out Windows install failure.
      All four paths are covered by tests.
- [x] Excel import (.xlsx/.xls) via `readxl`, Suggests-gated with a clear install
      message when absent. Multi-sheet workbooks expose a worksheet picker.
- [x] Composite date columns: Year + Quarter / Month / Day are assembled into a real
      date (`R/date_parts.R`), and aggregation is clamped to the finest part supplied.
      Added quarter and year support to `convert_months_to_horizon()`,
      `ts_frequency_for()` and `analyze_series()`.
- [x] Google Sheets import, implemented via the sheet's CSV export endpoint rather
      than `googlesheets4`: no OAuth round-trip (awkward in a local app), no
      credential storage, no extra dependency. Requires the sheet be shared as
      "Anyone with the link can view", which the UI states explicitly.
- [ ] Private (non-link-shared) Google Sheets, which would need `googlesheets4` and
      an auth flow. Only worth adding if the link-share route proves insufficient.

## 🚧 Known gaps vs. the hosted app (not yet ported)

These exist in the hosted Forecast Dashboard but not in this package. Listed so the
gap is explicit rather than discovered by surprise.

- [ ] **Population normalization / incidence.** `process_uploaded_data()` still carries
      the `pop_df`/`pop_date_col`/`pop_value_col`/`unit_divisor`/`pop_multiplier`/
      `pop_freq` arguments, but the app never exposes them, so only absolute values can
      be forecast. The hosted app's Data Import tab step 2 does this.
- [ ] **Individual-observation mode.** `process_uploaded_data(type = "individual")`
      counts one event per row into periods; the app hardcodes `type = "agg"`.
- [ ] **Holiday inconsistency / contingency analysis.** The hosted app cross-tabs
      holidays against the data: "Holidays with Non-Zero Data" and "Dates Always Zero
      or Missing" (flagged per date). Nothing equivalent here.
- [ ] **Fixed-holiday catalog** (Republic Day, Independence Day, Gandhi Jayanti,
      Christmas, Ambedkar Jayanti, Makar Sankranti) with a year-range slider.
- [ ] **Movable holidays via file upload** with date/label column mapping.
- [ ] **Per-holiday window settings** (lower_window / upper_window) and the window table.
- [ ] **Holiday label editing and row removal** from the compiled list.
- [ ] **Multi-window evaluation metrics.** Hosted scores Train / Last 6 Months /
      Last 2 Years / Manual Entry; this package scores one held-out window.
- [ ] **Prophet prior-grid comparison (A-D).** The package compares *different models*;
      it cannot yet compare four changepoint/seasonality prior settings of one model.
- [ ] **Plot appearance controls.** `plot_forecast_generic()` accepts show_trend /
      show_uncertainty / show_holidays / show_changepoints, but no UI exposes them, and
      there are no colour pickers.
- [ ] **Downloads.** Hosted offers processed-dataset CSV, forecast PNG and holiday CSV;
      the package only downloads generated code.

## 📘 Model Guide

- [x] Model Guide tab in the bundled app (`R/app_guide.R`), covering all 8 models,
      model parameters, evaluation metrics, holidays, the recommendation heuristic,
      and the Show Code panel. This was specified in the original plan but missed in
      the first implementation pass.
- [ ] Optional interactive parameter demo (the hosted app's Prophet demo), if useful
      locally where memory is not constrained.
