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

---

## 🛠 Structural Cleanup

- [ ] 📦 Convert app into R package with DESCRIPTION, NAMESPACE, run_app()
- [ ] 📁 Move all helpers, ui, and server files to `R/` directory
- [ ] 🔁 Replace manual `source()` calls with package imports
- [ ] 📥 Use `inst/extdata/` for demo datasets and internal references

---

## 📉 Model Strategy Refinement

- [ ] 🗑️ Fully remove ARIMA tab and server logic (retain for archival)
- [ ] 🔌 If revived, reintroduce ARIMA via toggle or external plug-in module
- [ ] 🧪 Consider dynamic benchmarking between Prophet vs ARIMA as opt-in

---

## 📥 Data Upload Enhancements

- [ ] 📊 Display summary stats on upload (e.g., min/max date, data completeness)
- [ ] ⏱️ Enable time zone adjustment for hourly data
- [ ] 🧪 Improve frequency detection with smarter heuristics