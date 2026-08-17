# Registers every built-in model with the registry (R/registry.R). This
# file must load last -- guaranteed by the explicit `Collate:` field in
# DESCRIPTION (not by the "zzz_" filename prefix; without a `Collate:`
# field, R falls back to a locale-dependent file sort order that is NOT
# guaranteed to be consistent across platforms, which caused a real
# "lazy loading failed" install error on Windows before Collate was
# added -- register_model() calls below reference functions like
# .prophet_fit that must already exist when this file's top-level code
# runs during package build).
#
# Adding a new model later: write a model_<name>.R with its fit/forecast
# functions (and optionally to_tibble/annotate), add one register_model()
# call here, and add the new file to DESCRIPTION's Collate field (anywhere
# before zzz_register_builtins.R).

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

# Only appears in list_models(available_only = TRUE) once the user installs
# torch — see model_lstm.R's header comment on verification status.
register_model(
  key = "lstm",
  label = "LSTM (Neural Network, requires torch)",
  fit = .lstm_fit,
  forecast = .lstm_forecast,
  to_tibble = .lstm_to_tibble,
  supports_holidays = FALSE,
  requires = "torch"
)
