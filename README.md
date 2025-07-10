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
│   └── female_births.csv
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
  - shiny, prophet, plotly, ggplot2, dplyr, lubridate, datamods, shinyjs, shinyBS, bslib, tibble, DT, shinycssloaders

Install all dependencies with:

```r
install.packages("pacman")
pacman::p_load(shiny, prophet, plotly, ggplot2, dplyr, lubridate, datamods,
               shinyjs, shinyBS, bslib, tibble, DT, shinycssloaders)


🙌 Acknowledgments
- Prophet by Meta (Facebook)
- Daily Female Births dataset by Jason Brownlee

![Version](https://img.shields.io/badge/version-v0.6.0-blue?style=flat-square)

