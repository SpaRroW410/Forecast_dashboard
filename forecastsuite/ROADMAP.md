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

- [x] Import and population sources are icon buttons (`R/ui_helpers.R`'s
      `icon_source_row()`/`wire_icon_source()`), matching the hosted app's original
      `.icon-vertical`/`.icon-btn` style, with the source name shown as hover-tooltip
      text via the native `title` attribute -- not a new text-radio list. Mechanically
      each icon click just drives a hidden `radioButtons()`, so every existing
      `conditionalPanel`/`input$fs_import_source` read is unaffected.
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

## ✅ Ported from the hosted app

- [x] **Population normalization / incidence.** Import tab gains an optional population
      table (file or global environment) with key/value columns, per-year or per-month
      basis, multiplier and unit divisor. Ordering is handled explicitly: rows sharing a
      period are summed **first**, and only the period total is divided by population --
      normalizing per row and then adding would sum rates.
- [x] **Full holiday system** (`R/app_holidays.R`): Sundays over a year range, the
      fixed-date catalog (Republic Day, Independence Day, Gandhi Jayanti, Christmas,
      Ambedkar Jayanti, Makar Sankranti), movable holidays uploaded as a file with
      date/label column mapping, manual entry (repeating or one-off), relabel and remove
      on the compiled list, per-holiday lower/upper windows, and a summary.
- [x] **Holiday consistency / contingency analysis**: "Holidays with non-zero data" and
      "Dates always zero or missing", the latter flagging whether each suspicious date is
      already declared -- the undeclared ones are the actual gap.
- [x] **Multi-window evaluation metrics**: Train, Last 6 Months, Last 2 Years and the
      held-out Test window. Windows longer than the series are skipped rather than
      reported as NA.
- [x] **Suggested hyperparameters in the recommendation table**, replacing the Prophet
      prior-grid comparison: measured trend/seasonal strength propose changepoint and
      seasonality priors, and ndiffs()/nsdiffs() propose d/D. p, q, P and Q are no
      longer hardcoded either -- `R/recommend.R`'s `.suggest_pq()` differences the
      series by the proposed d/D, then reads p/q off the leading run of significant
      lags in the PACF/ACF ("cuts off after lag k", the standard Box-Jenkins rule) and
      P/Q off whether that same 95% band is crossed at the seasonal lag. Verified
      against known synthetic AR(2)/MA(1)/white-noise processes.

- [x] **Individual-observation mode.** A "Data Format" radio (`fs_data_type`, Import
      tab) exposes `process_uploaded_data(type = "individual")` directly: one row per
      event, counted into periods, no Value column needed (its selector hides itself
      in this mode). Population normalization still composes on top of either format.
      Import now accepts single-column tables (the >= 2 columns guard was relaxed to
      >= 1, since individual mode only needs a date column).

- [x] **Plot appearance controls.** A "Plot Appearance" panel on the Model tab exposes
      show_trend / show_uncertainty / show_holidays / show_changepoints as checkboxes,
      plus `colourpicker::colourInput()` for the actual/forecast/trend/CI-fill colors.
      Both the on-screen plotly figure and its PNG download read the same inputs, so
      they always match.
- [x] **Downloads.** Processed-dataset CSV (Import tab), holiday CSV (Holidays tab),
      the single-model forecast plot as PNG, and the multi-model comparison plot as
      PNG (Model tab) -- all four render from scratch with base R graphics
      (`R/plot_png.R`) rather than a headless-browser screenshot tool like
      webshot2/orca, which need a browser or PhantomJS installed locally; that's
      exactly the kind of unverified, heavy dependency that caused the Windows
      install saga earlier in this package's history.

- [x] **Grouping variable.** An optional Import-tab column (`fs_group_col`, e.g.
      District/Sex/Product) splits the finalized dataset into one time series per
      distinct value, independent of the aggregate: `final_dataset()` always stays
      exactly what the ungrouped path always produced, and a parallel
      `grouped_series()` (named list, `R/grouping_utils.R`'s `split_by_group()`)
      holds the per-group split. Two checklists, not one: which values enter the
      finalized dataset at all (Import tab), and which of those get fit on a given
      Fit & Forecast click (Model tab, since importing 20 groups doesn't mean
      fitting all 20 every time). Fit & Forecast fits the chosen model across every
      selected group, then a "Viewing group" picker browses each one's plot/metrics
      -- the same single-series render code, redirected through one `active_fit()`
      resolver. "Compare Selected Models" deliberately stays single-group (compares
      against whichever group is currently in view, never N models x M groups) via
      the same `train_test_split()` -> `active_series()` indirection. A new "All
      Groups (overlay)" plot (`plot_group_overlay()`/`render_group_overlay_png()`)
      shows every fitted group's own actual history and forecast, same palette color
      per group (solid vs. dashed) -- genuinely new plotting code, not a reuse of
      the models-comparison overlay, since every group has its own actual series.
      Population normalization is group-aware: a population table with a matching
      group column normalizes each group by its own figure and the aggregate by the
      groups' summed population; a population table with no group breakdown only
      ever normalizes the aggregate (never guessed onto individual groups). The
      recommendation table becomes one wide table when grouping is active -- Model |
      Overall Score | Why | Suggested settings | one score column per included group
      -- sorted by Overall Score. The holiday consistency check gained a "Check
      against" scope (combined or one group), since a date that's zero in the
      aggregate can still hide a real, group-specific closure pattern. 57 new tests
      (real `shiny::testServer()` scenarios with synthetic multi-district/multi-sex
      data, plus a byte-for-byte ungrouped-path regression check).

- [x] **Bottom-up hierarchical reconciliation.** Once >=2 groups are fit, "Viewing
      group" gains a "Reconciled (bottom-up)" option: the aggregate forecast becomes
      the sum of the already-fit group forecasts (`R/reconciliation.R`'s
      `reconcile_bottom_up()`) -- always coherent by construction, no extra model fit.
      Point forecasts sum exactly; prediction intervals are summed too, with a
      documented caveat that this assumes perfectly correlated group errors (the
      standard bottom-up heuristic, not a proper covariance-aware combination). Built
      as a `fitted_model()`-shaped synthetic list so every existing single-series
      render/download/metrics output works on it unmodified via `active_fit()`.
      Offered even when only some configured groups were fit this run, but always
      labeled "partial: N of M configured groups" so it's never presented as the true
      grand total when it isn't. The "All Groups (overlay)" plot gains the reconciled
      series as one more traced-color entry.
- [x] **Rolling-origin cross-validation.** A separate "Run Cross-Validation" button
      (Model tab, distinct from Fit & Forecast, like Compare Selected Models) refits
      the currently-viewed series at K walk-forward, expanding-window folds
      (`R/rolling_cv.R`'s `build_cv_folds()`) instead of relying on one train/test
      split, reporting per-fold MASE/sMAPE/RMSE plus a Mean/SD summary row. Degrades
      to fewer folds than requested on a short series rather than erroring. Not
      `forecast::tsCV()` -- confirmed incompatible with this package's split
      fit()/forecast() adapter contract (Prophet doesn't fit `tsCV`'s unified-function
      shape at all) -- so it loops the existing `fit_one()` helper directly. Scoped to
      whichever single series is currently in view; never multiplies across groups.
- [x] **Save/load a project.** A cross-tab panel (Save/Load, visible from any tab)
      saves the finalized dataset(s), holidays, and every Model-tab/plot-appearance
      setting as one `.rds` file (`R/project_io.R`, base `saveRDS()`/`readRDS()`, no
      new dependency) and restores them in a fresh session with no re-import needed.
      Deliberately excludes already-fitted model objects: Prophet's Stan-backed fits
      carry an external pointer not guaranteed to survive a `saveRDS()`/`readRDS()`
      round-trip into a fresh R session, so loading a project clears `fitted_model()`/
      `grouped_fitted_models()` explicitly and you re-click Fit & Forecast yourself.
      `holidays_server_logic()` gained a `restore_holidays` param and now also returns
      its `windows` reactive, so per-holiday window settings survive a reload too, not
      just the baked-in finalized list.

45 new tests across the three features above, all real `shiny::testServer()`
scenarios (synthetic multi-group data, a save-then-load round trip with NO prior
import step in the loading session, and a short-series CV degradation check) --
456 total passing, 0 failures.

## 📘 Model Guide

- [x] Model Guide tab in the bundled app (`R/app_guide.R`), covering all 8 models,
      model parameters, evaluation metrics, holidays, the recommendation heuristic,
      and the Show Code panel. This was specified in the original plan but missed in
      the first implementation pass.
