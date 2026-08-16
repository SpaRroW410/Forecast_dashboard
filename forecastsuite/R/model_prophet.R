# Prophet adapter — reuses the fit/forecast split from the parent repo's
# helpers/modeling_functions.R::prepare_forecast(), split to match the
# registry's fit/forecast/to_tibble contract. Prophet-specific args
# (holidays_df, cp, season, holiday, exclude_sundays, yearly, weekly, daily)
# flow through fit()'s `...`; the daily/weekly seasonality flags are stashed
# as attributes on the fitted model so forecast() can pick the same future
# dataframe frequency without the caller re-passing them.

.prophet_fit <- function(train_df, date_agg = "day", holidays_df = NULL,
                          cp = 0.05, season = 10, holiday = 5,
                          exclude_sundays = TRUE,
                          yearly = TRUE, weekly = TRUE, daily = FALSE, ...) {
  data <- train_df
  if (exclude_sundays) {
    data <- data[!lubridate::wday(data$ds) %in% 1, ]
  }

  m <- prophet::prophet(
    changepoint.prior.scale = cp,
    seasonality.prior.scale = season,
    holidays = holidays_df,
    holidays.prior.scale = holiday,
    yearly.seasonality = FALSE,
    weekly.seasonality = FALSE,
    daily.seasonality  = FALSE
  )

  if (yearly) m <- prophet::add_seasonality(m, name = "yearly", period = 365.25, fourier.order = 10)
  if (weekly) m <- prophet::add_seasonality(m, name = "weekly", period = 7, fourier.order = 3)
  if (daily)  m <- prophet::add_seasonality(m, name = "daily", period = 1, fourier.order = 3)

  m <- prophet::fit.prophet(m, data)
  attr(m, "fs_daily") <- daily
  attr(m, "fs_weekly") <- weekly
  m
}

.prophet_forecast <- function(model, h, ...) {
  daily <- isTRUE(attr(model, "fs_daily"))
  weekly <- isTRUE(attr(model, "fs_weekly"))
  freq <- if (daily) "day" else if (weekly) "week" else "day"
  future <- prophet::make_future_dataframe(model, periods = h, freq = freq)
  stats::predict(model, future)
}

.prophet_to_tibble <- function(fc_obj, test_df) {
  cols <- intersect(c("ds", "yhat", "yhat_lower", "yhat_upper"), names(fc_obj))
  out <- fc_obj[, cols, drop = FALSE]
  out$ds <- as.Date(out$ds)
  tibble::as_tibble(out)
}
