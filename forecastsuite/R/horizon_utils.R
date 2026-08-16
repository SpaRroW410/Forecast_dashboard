# convert_months_to_horizon() adapted from the parent repo's
# helpers/modeling_functions.R. ts_frequency_for() generalizes the
# date_agg -> ts() frequency mapping first introduced in the hosted app's
# server/server_arima.R this session.

convert_months_to_horizon <- function(months, aggregation) {
  if (aggregation == "day") {
    return(months * 30)
  } else if (aggregation == "week") {
    return(ceiling(months * 30 / 7))
  } else if (aggregation == "month") {
    return(months)
  } else {
    stop("Unsupported aggregation type for forecasting horizon.")
  }
}

ts_frequency_for <- function(date_agg) {
  freq_map <- c(hour = 24, day = 365, week = 52, month = 12)
  if (is.null(date_agg) || !(date_agg %in% names(freq_map))) date_agg <- "day"
  freq_map[[date_agg]]
}
