# Registers every built-in model with the registry (R/registry.R).
#
# Registration happens inside .onLoad(), i.e. when the package is *loaded*,
# NOT at top level. This matters: top-level code runs during
# "byte-compile and prepare package for lazy loading" at install time, so
# top-level register_model() calls would populate .model_registry (an
# environment) during the build and force R to serialize that populated
# environment -- complete with closures -- into the lazy-load database.
# That is fragile across R versions/platforms and caused a real
# "ERROR: lazy loading failed" install failure on Windows. Building the
# registry at load time keeps install-time work to plain function
# definitions only, and is the conventional pattern for package-level
# mutable state.
#
# Adding a new model later: write a model_<name>.R with its fit/forecast
# functions (and optionally to_tibble/annotate), add the file to
# DESCRIPTION's Collate field, and add one register_model() call below.

register_builtin_models <- function() {
  register_model(
    key = "prophet",
    label = "Prophet",
    fit = .prophet_fit,
    forecast = .prophet_forecast,
    to_tibble = .prophet_to_tibble,
    supports_holidays = TRUE
  )

  register_model(
    key = "arima",
    label = "ARIMA",
    fit = .arima_fit,
    forecast = .arima_forecast,
    to_tibble = .forecast_pkg_to_tibble,
    supports_holidays = FALSE,
    annotate = .arima_annotate
  )

  register_model(
    key = "sarima",
    label = "SARIMA",
    fit = .sarima_fit,
    forecast = .sarima_forecast,
    to_tibble = .forecast_pkg_to_tibble,
    supports_holidays = FALSE,
    annotate = .arima_annotate
  )

  register_model(
    key = "ets",
    label = "ETS (Exponential Smoothing)",
    fit = .ets_fit,
    forecast = .ets_forecast,
    to_tibble = .forecast_pkg_to_tibble,
    supports_holidays = FALSE
  )

  register_model(
    key = "tbats",
    label = "TBATS",
    fit = .tbats_fit,
    forecast = .tbats_forecast,
    to_tibble = .forecast_pkg_to_tibble,
    supports_holidays = FALSE
  )

  register_model(
    key = "nnetar",
    label = "NNETAR (Neural Net)",
    fit = .nnetar_fit,
    forecast = .nnetar_forecast,
    to_tibble = .forecast_pkg_to_tibble,
    supports_holidays = FALSE
  )

  register_model(
    key = "holtwinters",
    label = "Holt-Winters",
    fit = .holtwinters_fit,
    forecast = .holtwinters_forecast,
    to_tibble = .forecast_pkg_to_tibble,
    supports_holidays = FALSE
  )

  # Only appears in list_models(available_only = TRUE) once the user
  # installs torch -- see model_lstm.R's header comment.
  register_model(
    key = "lstm",
    label = "LSTM (Neural Network, requires torch)",
    fit = .lstm_fit,
    forecast = .lstm_forecast,
    to_tibble = .lstm_to_tibble,
    supports_holidays = FALSE,
    requires = "torch"
  )

  invisible(TRUE)
}

.onLoad <- function(libname, pkgname) {
  register_builtin_models()
}
