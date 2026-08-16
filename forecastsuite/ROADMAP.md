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
- [ ] Combined multi-model trend plot for "Compare Selected Models" (currently only a
      metrics table) — generalizes the hosted app's "Combined Trend Comparison" plot
      in `server/server_forecast.R` to N registered models instead of 4 Prophet priors.

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

- [ ] Optional richer import (Google Sheets / copy-paste / env, matching the hosted
      app's `datamods`-based module) as a `Suggests`-gated enhancement — the plain
      `fileInput()` importer stays the default so this remains optional weight, same
      pattern already used for `torch`.
