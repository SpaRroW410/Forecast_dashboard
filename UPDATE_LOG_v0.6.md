# 🧭 Update Log — Version 0.6 (July 10, 2025)

## 🔧 Core Improvements

### 📥 Data Import
- ✅ Conditional population upload
- ✅ Aggregation frequency validated against actual dataset granularity
- ✅ Static preview tables for main and population data
- ✅ Hourly-to-daily aggregation supported
- ✅ Population normalization using 365.25-day base
- ✅ Tab visibility tied to user selections and readiness

### 📅 Holiday Tab
- ✅ Replaced checkbox toggles with `radioButtons` for effects & contingency
- ✅ Split contingency into:
  - Holidays with non-zero `y`
  - Month-day combinations always zero or missing
- ✅ Label editing and window configuration fully modular
- ✅ Combined preview table scrollable and sortable
- ✅ Safeguards against `NULL` in window settings

### 📈 Forecasting Tab
- ✅ Removed visual metrics plot for clarity
- ✅ Metrics now rendered as wide-format table comparing:
  - Train / Last 6 Months / Last 2 Years / Manual Test
- ✅ Combined trend plot uses `alpha = 0.5` for overlap clarity
- ✅ Metrics comparison for prior combinations A–D added
  - Tied to “Generate Combined Trend Plot” button
- ✅ Plotly range selector now anchored to recent dates using `stepmode = "backward"`

---

## 📦 Backend Utilities
- ✅ `safe_compute_metrics()` fallback for sparse data
- ✅ Label normalization (`str_trim()`, `str_to_title()`)
- ✅ Window defaulting logic in `apply_window_settings()`
- ✅ Clean metric pivoting with `pivot_wider()` for display

---

## 📤 Deployment Ready
- ✅ Modular structure ready for packaging:
  - `ui/`, `server/`, `helpers/`, `www/`
- ✅ `run_app()` can be generated for Shiny Connect
- ✅ Configurable versioning via `DESCRIPTION`, `UPDATE_LOG.md`, and GitHub tags

### 🧠 Memory Conservation
- ✅ Forecast module avoids loading model outputs unless triggered
- ✅ Sliders and UI states reset when toggles are disabled
- ✅ No unnecessary rendering of plots or metrics during idle interaction
- ✅ Helper functions skip expensive joins when data is missing or `NULL`
- ✅ Scrollable previews limit rendering load for large datasets

...

## 🗂 Structural Adjustments
- 🛑 ARIMA module deprecated from UI and server
  - Files retained for reference but excluded from active interface
  - Planning full removal or conversion in future release
