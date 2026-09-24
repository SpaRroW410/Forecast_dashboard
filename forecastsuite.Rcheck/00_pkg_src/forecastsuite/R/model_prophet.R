# Prophet adapter -- reuses the fit/forecast split from the parent repo's
# helpers/modeling_functions.R::prepare_forecast(), split to match the
# registry's fit/forecast/to_tibble contract. Prophet-specific args
# (holidays_df, cp, season, holiday, exclude_sundays, yearly, weekly, daily)
# flow through fit()'s `...`; the daily/weekly seasonality flags are stashed
# as attributes on the fitted model so forecast() can pick the same future
# dataframe frequency without the caller re-passing them.
#
# `prophet` is Suggests, not Imports (see DESCRIPTION): it pulls in
# rstan/StanHeaders, a heavy compiled Stan backend with a real history of
# CRAN check fragility (version-skew crashes on exit, past Windows/Rtools
# install failures) -- exactly the kind of dependency that shouldn't be
# force-loaded just by `library(forecastsuite)`. Isolated in its own file so
# no other part of the package needs to know or care whether prophet is
# installed, same as model_lstm.R's torch isolation. `list_models()` simply
# omits "prophet" until it's available (see `requires = "prophet"` in
# zzz_register_builtins.R).

#' Check whether the Prophet model is available
#'
#' The `"prophet"` model requires the optional `prophet` package. This
#' checks whether it's installed, without loading it.
#'
#' @return `TRUE` if `prophet` is installed, `FALSE` otherwise.
#' @export
#' @examples
#' prophet_available()
prophet_available <- function() {
  requireNamespace("prophet", quietly = TRUE)
}

.require_prophet_or_stop <- function() {
  if (!prophet_available()) {
    stop(
      "The 'prophet' package is required for Prophet forecasting. Install it with:\n",
      "  install.packages(\"prophet\")\n",
      "Prophet is optional -- every other model in forecastsuite works without it.",
      call. = FALSE
    )
  }
}

# Returns the prophet namespace for runtime use, e.g. ph$prophet(...).
#
# Deliberately NOT written as static `prophet::fn()` calls: prophet is a
# Suggests dependency, so it is normally absent at install time, and R's
# byte-compiler attempts to resolve `pkg::name` references while compiling.
# Looking the namespace up at runtime instead leaves nothing for the
# compiler to resolve, so this file compiles cleanly whether or not prophet
# is installed. Callers must invoke .require_prophet_or_stop() first (this
# does so itself), so a missing prophet still produces the friendly error
# above rather than an obscure namespace failure.
.prophet_ns <- function() {
  .require_prophet_or_stop()
  asNamespace("prophet")
}

.prophet_fit <- function(train_df, date_agg = "day", holidays_df = NULL,
                          cp = 0.05, season = 10, holiday = 5,
                          exclude_sundays = TRUE,
                          yearly = TRUE, weekly = TRUE, daily = FALSE, ...) {
  ph <- .prophet_ns()

  data <- train_df
  if (exclude_sundays) {
    data <- data[!lubridate::wday(data$ds) %in% 1, ]
  }

  m <- ph$prophet(
    changepoint.prior.scale = cp,
    seasonality.prior.scale = season,
    holidays = holidays_df,
    holidays.prior.scale = holiday,
    yearly.seasonality = FALSE,
    weekly.seasonality = FALSE,
    daily.seasonality  = FALSE
  )

  if (yearly) m <- ph$add_seasonality(m, name = "yearly", period = 365.25, fourier.order = 10)
  if (weekly) m <- ph$add_seasonality(m, name = "weekly", period = 7, fourier.order = 3)
  if (daily)  m <- ph$add_seasonality(m, name = "daily", period = 1, fourier.order = 3)

  m <- ph$fit.prophet(m, data)
  attr(m, "fs_daily") <- daily
  attr(m, "fs_weekly") <- weekly
  m
}

.prophet_forecast <- function(model, h, ...) {
  ph <- .prophet_ns()
  daily <- isTRUE(attr(model, "fs_daily"))
  weekly <- isTRUE(attr(model, "fs_weekly"))
  freq <- if (daily) "day" else if (weekly) "week" else "day"
  future <- ph$make_future_dataframe(model, periods = h, freq = freq)
  stats::predict(model, future)
}

.prophet_to_tibble <- function(fc_obj, test_df) {
  cols <- intersect(c("ds", "yhat", "yhat_lower", "yhat_upper"), names(fc_obj))
  out <- fc_obj[, cols, drop = FALSE]
  out$ds <- as.Date(out$ds)
  tibble::as_tibble(out)
}
