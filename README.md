# 📈 Prophet Forecast Dashboard

**Current Version:** `v0.6.0` — released July 10, 2025  

A modular Shiny application for time series forecasting using [Facebook Prophet](https://facebook.github.io/prophet/). This dashboard allows users to import data, configure holiday effects, tune model priors, compare ARIMA and Prophet forecasts, and explore model behavior through interactive visualizations.

---

## 🚀 Features

- 📥 **Data Import Panel**: Upload and preview time series data
- 📆 **Holiday Configuration**: Add, edit, and visualize holiday effects
- 🔮 **Prophet Forecasting**:
  - Tune changepoint and seasonality priors
  - Visualize uncertainty intervals, trend, and changepoints
  - Compare actual vs forecast in a test window
- 📊 **ARIMA Forecasting**: Compare Prophet with ARIMA using the same dataset
- 🧪 **Model Guide Tab**:
  - Learn about Prophet components and parameters
  - Interactive demo using the Daily Female Births dataset
- 📤 **Modular Architecture**: Cleanly separated UI and server logic for scalability

---

## 📂 Folder Structure

## 📂 Folder Structure

```text
forecastv0.5/
├── app.R
├── data/
│   └── daily-total-female-births.csv
├── ui/
│   ├── ui_tab1_import.R
│   ├── ui_tab2_holidays.R
│   ├── ui_tab3_forecast.R
│   ├── ui_tab4_arima.R
│   └── model_guide_tab.R
├── server/
│   ├── server_data_import.R
│   ├── server_holidays.R
│   ├── server_forecast.R
│   ├── server_arima.R
│   └── model_guide_server.R
├── helpers/
│   ├── data_utils.R
│   ├── modeling_functions.R
│   ├── plot_utils.R
│   ├── metric_utils.R
│   └── holidays_helpers.R
├── www/
│   └── styles.css
└── README.md
```



---

## 📦 Requirements

- R (≥ 4.1)
- Packages:
  - shiny, tibble, shinyjs, shinyBS, DT, bslib, datamods, dplyr, lubridate, ggplot2, prophet, plotly, shinycssloaders, tidyr, colourpicker, zoo, forecast, stringr, readxl

Install all dependencies with:

```r
install.packages("pacman")
pacman::p_load(shiny, tibble, shinyjs, shinyBS, DT, bslib, datamods, dplyr,
               lubridate, ggplot2, prophet, plotly, shinycssloaders, tidyr,
               colourpicker, zoo, forecast, stringr, readxl)
```

---

## 🔒 Reproducible environment (renv)

`renv.lock` pins every package above to an exact, reproducible version. **It's
generated, never hand-edited**, from an R session that already has this app's real
dependencies installed:

```r
Rscript generate_renv_lock.R
```

(or `source("generate_renv_lock.R")`). The first run also scaffolds renv's own project
files (`.Rprofile`, `renv/activate.R`, `renv/settings.json`); `.renvignore` excludes the
`forecastsuite/` package subdirectory from the dependency scan, for the same reason
`.rscignore` does below. Commit the resulting `renv.lock` (and the scaffolded files, if
this is the first run). Anyone else on the project can then get the exact same package
versions with `renv::restore()`.

**Re-run it and commit the update whenever `app.R`'s package list changes** -- same
trigger as `manifest.json` below. The two files are independent and complementary:
`renv.lock` is for local/CI reproducibility via `renv::restore()`, `manifest.json` is
Connect Cloud's own deploy descriptor -- neither depends on the other.

---

## ☁️ Deploying to Posit Connect Cloud

Connect Cloud requires a `manifest.json` in the repository for any Shiny-for-R
deployment from GitHub -- it tells Connect Cloud which R version and which package
versions to install. **It's generated, never hand-edited**, from an R session that
already has this app's real dependencies installed (the `pacman::p_load(...)` list
above):

```r
Rscript generate_manifest.R
```

(or `source("generate_manifest.R")` from an R session where those packages are already
installed). Commit the resulting `manifest.json`. `.rscignore` excludes the
`forecastsuite/` package subdirectory from the scan, since it's a separate, independently
versioned package with its own dependency set, not part of this app.

**Re-run it and commit the update whenever `app.R`'s package list changes** -- a stale
manifest is a common cause of Connect Cloud deploy failures.

---

🙌 Acknowledgments
- Prophet by Meta (Facebook)
- Daily Female Births dataset by Jason Brownlee

![Version](https://img.shields.io/badge/version-v0.6.0-blue?style=flat-square)

