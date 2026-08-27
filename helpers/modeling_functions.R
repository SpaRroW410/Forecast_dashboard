# Maps the app's aggregation choice to a sensible ts() seasonal frequency.
# Shared by the ARIMA and SARIMA tabs (server_arima.R, server_sarima.R) --
# same name as forecastsuite's equivalent helper, for consistency.
ts_frequency_for <- function(date_agg) {
  freq_map <- c(hour = 24, day = 365, week = 52, month = 12)
  if (is.null(date_agg) || !(date_agg %in% names(freq_map))) date_agg <- "day"
  freq_map[[date_agg]]
}

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