# convert_months_to_horizon() adapted from the parent repo's
# helpers/modeling_functions.R, extended here with quarter/year so data
# split across Year + Quarter columns can be aggregated at its own
# granularity (see R/date_parts.R). ts_frequency_for() generalizes the
# date_agg -> ts() frequency mapping first introduced in the hosted app's
# server/server_arima.R.

convert_months_to_horizon <- function(months, aggregation) {
  switch(aggregation,
    hour    = months * 30 * 24,
    day     = months * 30,
    week    = ceiling(months * 30 / 7),
    month   = months,
    quarter = max(1, ceiling(months / 3)),
    year    = max(1, ceiling(months / 12)),
    stop("Unsupported aggregation type for forecasting horizon.")
  )
}

ts_frequency_for <- function(date_agg) {
  freq_map <- c(hour = 24, day = 365, week = 52, month = 12, quarter = 4, year = 1)
  if (is.null(date_agg) || !(date_agg %in% names(freq_map))) date_agg <- "day"
  freq_map[[date_agg]]
}
