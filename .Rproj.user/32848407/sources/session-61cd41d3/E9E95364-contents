convert_months_to_horizon <- function(months, aggregation) {
  if (aggregation == "day") {
    return(months * 30)  # Approximate days
  } else if (aggregation == "week") {
    return(ceiling(months * 30 / 7))  # Approximate weeks
  } else if (aggregation == "month") {
    return(months)  # No change needed
  } else {
    stop("Unsupported aggregation type for forecasting horizon.")
  }
}


prepare_forecast <- function(data, holidays_df, cp, season, holiday, horizon,
                             exclude_sundays = TRUE,
                             yearly = TRUE, weekly = TRUE, daily = FALSE) {
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
  
  # Determine frequency
  freq <- if (daily) "day" else if (weekly) "week" else "day"  # Prophet doesn't support "month" directly
  
  future <- prophet::make_future_dataframe(m, periods = horizon, freq = freq)
  forecast <- predict(m, future)
  
  list(model = m, forecast = forecast, train = data)
}