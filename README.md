# 📈 Prophet Forecast Dashboard

**Current Version:** `v0.7.0`

A modular Shiny application for time series forecasting using [Facebook Prophet](https://facebook.github.io/prophet/), ARIMA, and SARIMA. This dashboard allows users to import data (CSV/TSV/Excel/URL/pasted text), configure holiday effects, tune model priors, fit Prophet/ARIMA/SARIMA forecasts, and explore model behavior through interactive visualizations. For heavier multi-model analysis (ETS, TBATS, NNETAR, Holt-Winters, LSTM, grouping, ensembling, cross-validation, and more), see the companion [`forecastsuite`](forecastsuite/) R package, installable and runnable locally with no hosting-tier memory limits -- see the in-app **Application Guide** tab for install instructions.

---

## 🚀 Features

- 📥 **Data Import Panel**: Upload (CSV/TSV/Excel, multi-sheet workbooks included), fetch by URL, or paste delimited text; preview and aggregate to hourly/daily/weekly/monthly
- 📆 **Holiday Configuration**: Add, edit, and visualize holiday effects, including importing a movable-holidays list from an Excel/CSV file (a downloadable 5-row example is provided) and a calendar-vs-declared consistency check
- 🔮 **Prophet Forecasting**: Tune changepoint and seasonality priors, visualize uncertainty intervals/trend/changepoints, and evaluate against train/6-month/2-year/held-out test windows
- 📊 **ARIMA Forecasting**: Non-seasonal `auto.arima()` order search on the same dataset
- 🌊 **SARIMA Forecasting**: Seasonal `auto.arima()` order search, for series with repeating seasonal cycles ARIMA alone won't capture
- 🧪 **Model Guide Tab**: Learn about Prophet/ARIMA/SARIMA's components and parameters, with an interactive demo using the Daily Female Births dataset
- 📘 **Application Guide Tab**: A step-by-step walkthrough of the forecasting workflow (import → holidays → fit → evaluate), plus install/run instructions for the `forecastsuite` companion package
- 📤 **Modular Architecture**: Cleanly separated UI and server logic for scalability
- ☁️ **Posit Connect Cloud ready**: `manifest.json`/`renv.lock` generator scripts for reproducible, hosted deployment (see below)

---

## 📂 Folder Structure

```text
Forecast_dashboard/
├── app.R
├── data/
│   ├── daily-total-female-births.csv
│   └── example_holidays.csv
├── ui/
│   ├── ui_tab1_import.R
│   ├── ui_tab2_holidays.R
│   ├── ui_tab3_forecast.R
│   ├── ui_tab4_arima.R
│   ├── ui_tab_sarima.R
│   ├── ui_tab_app_guide.R
│   └── model_guides.R
├── server/
│   ├── server_data_import.R
│   ├── server_holidays.R
│   ├── server_forecast.R
│   ├── server_arima.R
│   ├── server_sarima.R
│   └── model_guide_server.R
├── helpers/
│   ├── data_utils.R
│   ├── modeling_functions.R
│   ├── plot_utils.R
│   ├── metric_utils.R
│   ├── holidays_helpers.R
│   └── recommend_utils.R
├── module/
│   └── import_panel_module.R
├── www/
│   └── styles.css
├── forecastsuite/          # companion R package -- see forecastsuite/README.md
├── generate_manifest.R     # Posit Connect Cloud manifest.json generator
├── generate_renv_lock.R    # renv.lock generator
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

The script points `options(repos = ...)` at Posit Package Manager's binary CRAN mirror
before generating the manifest, so each package (`prophet` in particular) records a
repository Connect Cloud can pull a precompiled binary from instead of compiling from
source. This matters: `prophet` bundles a Stan model (`rstan`/`StanHeaders`), one of the
slowest-compiling dependencies in the R ecosystem -- a source install can take long
enough to trip Connect Cloud's worker-startup timeout and fail the deploy with "Unable
to connect to worker ...; startup took too long" before the app ever starts.

**Re-run it and commit the update whenever `app.R`'s package list changes** -- a stale
manifest is a common cause of Connect Cloud deploy failures.

---

🙌 Acknowledgments
- Prophet by Meta (Facebook)
- Daily Female Births dataset by Jason Brownlee

![Version](https://img.shields.io/badge/version-v0.7.0-blue?style=flat-square)

