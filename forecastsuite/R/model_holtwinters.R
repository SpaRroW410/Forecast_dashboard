.holtwinters_fit <- function(train_df, date_agg = "day", ...) {
  ts_train <- .prep_train_ts(train_df, date_agg)
  # Unlike ets()/tbats()/auto.arima(), stats::HoltWinters() hard-errors
  # ("time series has no or less than 2 periods") without at least two full
  # seasonal cycles — fall back to a non-seasonal fit rather than crash.
  if (length(ts_train) < 2 * stats::frequency(ts_train)) {
    stats::HoltWinters(ts_train, gamma = FALSE)
  } else {
    stats::HoltWinters(ts_train)
  }
}
.holtwinters_forecast <- function(model, h, ...) forecast::forecast(model, h = h)
