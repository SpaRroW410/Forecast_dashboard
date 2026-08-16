# 🔮 forecastsuite Roadmap

Forward-looking items specific to the local package (the hosted app's roadmap lives in
`../ROADMAP_v0.7.md` at the repo root).

---

## 🧑‍💻 Show-the-code panel (esquisse-style)

- [ ] Add a collapsible panel at the bottom of the Model tab that displays the R code
      equivalent of whatever was just fit/forecast/plotted — mirroring `esquisse`'s live
      code preview for its drag-and-drop ggplot2 builder, but generated from the
      registry's `fit`/`forecast`/`to_tibble` calls instead of a plot spec.
- [ ] Regenerate the code block on each "Fit & Forecast" / "Compare Selected Models"
      click (not on every slider tweak) — show the code that *was* run, not a live
      preview of a hypothetical run, to avoid re-rendering noise.
- [ ] Render as a monospace, syntax-highlighted block (`shiny::tags$pre`/`tags$code`
      is enough to start; a proper R highlighter can come later) with a "Copy" button
      (`shinyjs::runjs` clipboard write, or the `rclipboard` package if a dependency is
      acceptable) and a "Download as .R" button.
- [ ] Cover both the single-model fit path and the N-way comparison path, since both
      currently hide their `do.call(entry$fit, ...)` construction inside
      `R/app_server.R` — the code panel should reconstruct a runnable, standalone
      snippet a user could paste into their own script (i.e. explicit `library(forecastsuite)`,
      explicit argument values, no leftover Shiny reactivity).

## 📈 Plotting & comparison parity with the hosted app

- [ ] `model_shared.R::.forecast_pkg_to_tibble()` currently only keeps `$mean` from
      `forecast::forecast()`'s output, discarding `$lower`/`$upper` prediction
      intervals that are already computed — thread those through as `yhat_lower`/
      `yhat_upper` so ARIMA/SARIMA/ETS/TBATS/NNETAR/Holt-Winters get the same
      uncertainty ribbon Prophet already shows in `plot_forecast_generic()`.
- [ ] Combined multi-model trend plot for "Compare Selected Models" (currently only a
      metrics table) — generalizes the hosted app's "Combined Trend Comparison" plot
      in `server/server_forecast.R` to N registered models instead of 4 Prophet priors.

## 🧪 Verification still needed locally (see model_lstm.R and README)

- [ ] Install `torch` and confirm the LSTM adapter actually trains/forecasts —
      written and statically reviewed only so far; this sandbox has no CRAN access.
- [ ] `R CMD build` / `R CMD check` / `R CMD INSTALL` end-to-end — `devtools`/
      `rcmdcheck` aren't installable here either.
- [ ] Launch `run_app()` in a real browser and click through every tab — `shiny::testServer`
      exercised the server logic headlessly this session, but never rendered anything.

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
