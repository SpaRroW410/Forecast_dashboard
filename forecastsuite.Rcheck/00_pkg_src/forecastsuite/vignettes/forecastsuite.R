## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(collapse = TRUE, comment = "#>", fig.width = 7, fig.height = 4)

## -----------------------------------------------------------------------------
library(forecastsuite)

vapply(list_models(available_only = TRUE), function(m) m$key, character(1))

## -----------------------------------------------------------------------------
set.seed(1)
n <- 120
ds <- as.Date("2023-01-01") + 0:(n - 1)
y <- 100 + 15 * sin(2 * pi * seq_len(n) / 7) + seq_len(n) * 0.2 + rnorm(n, sd = 3)

train_df <- tibble::tibble(ds = ds[1:100], y = y[1:100])
test_df  <- tibble::tibble(ds = ds[101:120], y = y[101:120])

model <- get_model("arima")
fit_obj <- model$fit(train_df, date_agg = "day", auto = TRUE)
fc_raw  <- model$forecast(fit_obj, h = 20)
fc_tib  <- model$to_tibble(fc_raw, test_df)

head(fc_tib)

## -----------------------------------------------------------------------------
safe_compute_metrics(fc_tib, test_df, label = "Test")

## -----------------------------------------------------------------------------
plot_forecast_generic(fc_tib, train_df = train_df, subtitle = model$annotate(fit_obj))

## -----------------------------------------------------------------------------
decomp <- decompose_series(train_df, date_agg = "day")
head(decomp)

## -----------------------------------------------------------------------------
anomalies <- detect_anomalies(train_df, date_agg = "day", method = "iqr", threshold = 1.5)
anomalies[anomalies$is_anomaly, ]

## -----------------------------------------------------------------------------
resid_diag <- compute_residual_diagnostics(fc_tib, test_df)
resid_diag[c("ljung_box_p", "shapiro_p", "n")]

## -----------------------------------------------------------------------------
group_correlation_matrix(list(
  A = tibble::tibble(ds = ds, y = y),
  B = tibble::tibble(ds = ds, y = y * 0.5 + rnorm(n, sd = 1))
))

