# 🔮 Planned Improvements — Version 0.7

A preview of enhancements aimed at improving model control, visual clarity, performance, and forecasting flexibility.

---

## 📈 Forecasting Enhancements

- [ ] ✨ Auto-highlight best performing prior (A–D) based on RMSE or MASE
- [ ] ✨ Add tooltip descriptions for each evaluation metric
- [ ] [ ] Option to export metrics table as CSV for external use
- [ ] [ ] Support user-defined evaluation windows (custom date ranges)
- [ ] [ ] Improve changepoint visibility in all forecast plots

---

## 🧠 Manual & Hybrid Changepoints

- [ ] 🔧 Add ability to manually specify changepoints with optional titles (e.g., “Price Shock”, “Policy Start”)
- [ ] 🔧 UI components:
      - Date input for manual changepoint
      - Text input for changepoint label
- [ ] 🔧 Toggle between changepoint strategies:
      - Auto
      - Manual
      - Combined
- [ ] 🔧 Annotated display of changepoints on plots with labeled markers

---

## 📊 Visualization UX

- [ ] 🎨 Toggle visibility of Plotly traces (e.g., Forecast, Actual, Uncertainty)
- [ ] 🎨 Add legend interactivity for selective display
- [ ] 🎨 Optional annotations for changepoints or holidays
- [ ] 🎨 Color-code holidays by origin type (Fixed / Movable / Manual)

---

## 🧠 Memory Optimization

- [ ] 💾 Flush unused reactive stores after finalization or tab switch
- [ ] 💾 Prevent repeated rebuilds of identical forecast objects
- [ ] 💾 Profile and benchmark memory footprint under heavy usage
- [ ] 📦 Migrate large data frames to `data.table` for faster filtering and slicing
- [ ] 📦 Use `arrow::open_dataset()` to read partitioned datasets without loading into RAM
- [ ] 🔄 Convert long-format tables (e.g., forecast traces, contingency rows) into `arrow::Table` for lightweight preview rendering
- [ ] 🧪 Compare memory profiles of `tibble`, `data.table`, and `arrow` under UI interaction and reactivity

---

## 🛠 Structural Cleanup

- [x] 📦 Convert app into R package with DESCRIPTION, NAMESPACE, run_app() — done as the separate `forecastsuite/` package (see its own `ROADMAP.md`), not a conversion of this hosted app itself. The hosted app deliberately stays a plain `source()`-based Shiny deployment so it keeps working on the free Shiny Server tier without a package install step.
- [ ] 📁 Move all helpers, ui, and server files to `R/` directory — not planned for the hosted app itself, per above; already true for `forecastsuite/R/`.
- [ ] 🔁 Replace manual `source()` calls with package imports — same reasoning; out of scope for the hosted app.
- [x] 📥 Use `inst/extdata/` for demo datasets and internal references — done in `forecastsuite/inst/extdata/`.

---

## 📉 Model Strategy Refinement

- [x] 🔌 ARIMA tab reactivated (`auto.arima`, no holiday support) with a Prophet vs. ARIMA comparison table at the end of the tab
- [ ] 🧪 Consider further dynamic benchmarking options between Prophet vs ARIMA

---

## 📥 Data Upload Enhancements

- [ ] 📊 Display summary stats on upload (e.g., min/max date, data completeness)
- [ ] ⏱️ Enable time zone adjustment for hourly data
- [ ] 🧪 Improve frequency detection with smarter heuristics

## 📴 Offline Availability

- [x] 📦 Convert app into an installable R package — done as `forecastsuite/` (`DESCRIPTION`, `NAMESPACE`, `R/` structure, `run_app()` entry point).
- [x] 🖥️ Support launching via `run_app()` without Shiny Server or internet — `forecastsuite::run_app()`.
- [x] 📁 Bundle all internal datasets and stylesheets in `inst/extdata/` and `inst/www/` — done in `forecastsuite/`.
- [x] 📄 Create offline README and reproducible install instructions — `forecastsuite/README.md` (`remotes::install_local("forecastsuite")`).
- [ ] 🧪 Test compatibility across local RStudio environments and portable R distributions — still needs a real local run; see `forecastsuite/ROADMAP.md`.
- [ ] 💡 Explore optional standalone binaries (e.g., via `shinyloadtest` or Electron) for deployment on machines without R installed

---

## 📌 Pending decisions

- Plotly interactive forecast is now an opt-in toggle (default **off**) on the Forecast & Evaluation tab, to save memory on the 1GB free Shiny server tier. Still to decide: keep it as a permanent opt-in toggle, or fully remove plotly and its dependency from the app.

---

## 📦 See also: forecastsuite package roadmap

Package-specific forward-looking items (an esquisse-style "show the code" panel for
the Model tab, prediction-interval parity across all adapters, package hygiene,
verification still needed locally) now live in `forecastsuite/ROADMAP.md` rather than
here, since they apply only to the local package and not this hosted app.