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
├── generate_manifest.R     # Posit Connect Cloud manifest.json generator (run by CI)
├── tests/                  # hosted-app tests (helpers + headless smoke test)
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
install.packages(c("shiny", "tibble", "shinyjs", "shinyBS", "DT", "bslib", "datamods",
                   "dplyr", "lubridate", "ggplot2", "prophet", "plotly", "shinycssloaders",
                   "tidyr", "colourpicker", "zoo", "forecast", "stringr", "readxl"))
```

`app.R` loads them with plain `library()` calls (it no longer uses `pacman`, which
silently installs missing packages at start-up -- on a hosted runtime that turns a
missing dependency into a slow install inside the start-up timeout instead of a clear
error).

### Running the tests

```bash
cd tests && NOT_CRAN=true Rscript testthat.R
```

`tests/testthat/` holds the hosted app's own tests (the `forecastsuite` package's
tests live separately in `forecastsuite/tests/`): Prophet forecast length/frequency
checks, and a headless-browser smoke test (`shinytest2`, needs Chrome) that replays the
demo-data flow -- import → process → forecast → holidays → *Apply Window Settings* →
finalize → forecast → ARIMA → SARIMA -- and fails on any disconnect or server error.

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

Connect Cloud deploys from the `manifest.json` in the repository: it reads the R version
and the exact package versions to install from it. **It is generated by CI, never
hand-edited and not generated on Windows/macOS.**

**How it's produced.** The *Hosted app CI* workflow
(`.github/workflows/hosted-app.yaml`) runs on every push that touches the app. On Linux
with R 4.5 it installs the app's packages from **one dated Posit Package Manager
snapshot** (`P3M_SNAPSHOT`), runs the tests in `tests/testthat/`, and only if they pass
runs `Rscript generate_manifest.R --install` and commits `manifest.json` back if it
changed. The generator **refuses to write** a manifest if any pinned version isn't
current in that snapshot (otherwise the host would have to compile it from source), if
the R version is outside Connect Cloud's documented 4.0.0–4.6.0 range, or if tooling or
package-only dependencies (`rsconnect`, `renv`, `testthat`, `torch`, `forecastsuite`)
leak into the app.

To move to newer package versions, change `P3M_SNAPSHOT` in the workflow (and the default
in `generate_manifest.R`), push, and let CI test and regenerate.

**`.rscignore` syntax.** rsconnect matches **exact file/directory names, one per line, per
directory -- no globs, no trailing `/`, no comments**. A gitignore-style `forecastsuite/`
line silently matches nothing (that is how the whole package and a 13 MB
`forecastsuite.Rcheck/` directory used to end up in the deployment bundle). The current
file excludes the package, its build outputs, the generator scripts, `tests/`, `docs/`
and `.github/`, leaving only the app's own files in the bundle.

**Recommended deploy setup.** Point Connect Cloud at a branch that only receives commits
after CI is green (e.g. a `deploy` branch fast-forwarded from `main`), so a bad change can
never reach the live app; rolling back is a one-commit revert.

**Why this matters (history).** Earlier deploys failed with *"Unable to connect to worker
after 60.00 seconds; startup took too long"*. The app itself starts in ~3 s; the time went
on package installation. The previous manifest was written on Windows (R 4.6.1, above the
documented range) and hand-patched, and 31 of its pinned versions were only available as
source from the CRAN archive, so they had to be compiled (StanHeaders, RcppArmadillo,
RcppParallel, data.table, ...). See `docs/audit/2026-11-03-deployment-ui-audit.md`.

---

🙌 Acknowledgments
- Prophet by Meta (Facebook)
- Daily Female Births dataset by Jason Brownlee

![Version](https://img.shields.io/badge/version-v0.7.0-blue?style=flat-square)

