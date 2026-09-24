# convert_months_to_horizon() adapted from the parent repo's
# helpers/modeling_functions.R, extended here with quarter/year so data
# split across Year + Quarter columns can be aggregated at its own
# granularity (see R/date_parts.R). ts_frequency_for() generalizes the
# date_agg -> ts() frequency mapping first introduced in the hosted app's
# server/server_arima.R.

#' Convert a forecast horizon in months to periods
#'
#' @param months Numeric, the horizon in months (as set by the app's
#'   "Forecast Horizon (months)" slider).
#' @param aggregation One of `"hour"`, `"day"`, `"week"`, `"month"`,
#'   `"quarter"`, `"year"` -- the series' aggregation frequency.
#'
#' @return A numeric horizon in the same units as `aggregation` (e.g. days,
#'   for `aggregation = "day"`), suitable for a model's `forecast(model, h)`
#'   call.
#' @export
#' @examples
#' convert_months_to_horizon(12, "day")
#' convert_months_to_horizon(12, "month")
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

#' Map an aggregation frequency to a ts() seasonal frequency
#'
#' @param date_agg One of `"hour"`, `"day"`, `"week"`, `"month"`,
#'   `"quarter"`, `"year"`; anything else (including `NULL`) defaults to
#'   `"day"`.
#'
#' @return A single integer, suitable for `stats::ts(y, frequency = ...)`.
#' @export
#' @examples
#' ts_frequency_for("month")
ts_frequency_for <- function(date_agg) {
  freq_map <- c(hour = 24, day = 365, week = 52, month = 12, quarter = 4, year = 1)
  if (is.null(date_agg) || !(date_agg %in% names(freq_map))) date_agg <- "day"
  freq_map[[date_agg]]
}
