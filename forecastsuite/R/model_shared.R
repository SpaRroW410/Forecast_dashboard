# Shared helpers used by the forecast-package-based adapters (ARIMA, SARIMA,
# ETS, TBATS, NNETAR, Holt-Winters), since forecast::forecast() returns a
# uniform object with a $mean vector across all of these model classes —
# the same pattern proven in the hosted app's server/server_arima.R.

.forecast_pkg_to_tibble <- function(fc_obj, test_df) {
  h <- length(fc_obj$mean)
  n <- min(h, nrow(test_df))
  tibble::tibble(
    ds   = test_df$ds[seq_len(n)],
    yhat = as.numeric(fc_obj$mean)[seq_len(n)]
  )
}

.prep_train_ts <- function(train_df, date_agg) {
  y <- zoo::na.approx(train_df$y, na.rm = FALSE)
  y[is.na(y)] <- mean(y, na.rm = TRUE)
  stats::ts(y, frequency = ts_frequency_for(date_agg))
}
