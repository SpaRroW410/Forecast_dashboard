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

## 📘 Model Guide

- [x] Model Guide tab in the bundled app (`R/app_guide.R`), covering all 8 models,
      model parameters, evaluation metrics, holidays, the recommendation heuristic,
      and the Show Code panel. This was specified in the original plan but missed in
      the first implementation pass.
