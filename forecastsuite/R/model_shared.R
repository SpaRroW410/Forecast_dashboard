# Shared helpers used by the forecast-package-based adapters (ARIMA, SARIMA,
# ETS, TBATS, NNETAR, Holt-Winters), since forecast::forecast() returns a
# uniform object with a $mean vector across all of these model classes —
# the same pattern proven in the hosted app's server/server_arima.R.

.forecast_pkg_to_tibble <- function(fc_obj, test_df) {
  h <- length(fc_obj$mean)
  n <- min(h, nrow(test_df))
  idx <- seq_len(n)

  out <- tibble::tibble(
    ds   = test_df$ds[idx],
    yhat = as.numeric(fc_obj$mean)[idx]
  )

  # forecast::forecast() always computes prediction intervals ($lower/
  # $upper, one column per $level e.g. 80%/95%) -- surface the first
  # (narrowest, typically 80%) level as yhat_lower/yhat_upper so these
  # models get the same uncertainty ribbon Prophet already has in
  # plot_forecast_generic(), instead of silently discarding them.
  if (!is.null(fc_obj$lower) && !is.null(fc_obj$upper) && ncol(as.matrix(fc_obj$lower)) >= 1) {
    lower_mat <- as.matrix(fc_obj$lower)
    upper_mat <- as.matrix(fc_obj$upper)
    out$yhat_lower <- as.numeric(lower_mat[idx, 1])
    out$yhat_upper <- as.numeric(upper_mat[idx, 1])
  }

  out
}

.prep_train_ts <- function(train_df, date_agg) {
  y <- zoo::na.approx(train_df$y, na.rm = FALSE)
  y[is.na(y)] <- mean(y, na.rm = TRUE)
  stats::ts(y, frequency = ts_frequency_for(date_agg))
}
