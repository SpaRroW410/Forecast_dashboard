# The pluggable model registry. Every model is registered as a small set of
# functions sharing one contract:
#   fit(train_df, date_agg, ...)       -> model_obj
#   forecast(model_obj, h, ...)        -> raw_forecast_obj
#   to_tibble(raw_forecast_obj, test_df) -> tibble(ds, yhat[, yhat_lower, yhat_upper])
#   annotate(model_obj) -> character(1)   [optional; e.g. "ARIMA(2,1,1)(1,0,0)[12]"]
#
# Adding a new model later is one file (following the model_*.R pattern)
# plus one register_model() call in zzz_register_builtins.R — nothing else
# in the registry, UI, or metrics/plotting pipeline needs to change.

.model_registry <- new.env(parent = emptyenv())

register_model <- function(key, label, fit, forecast, to_tibble,
                            supports_holidays = FALSE, requires = NULL,
                            annotate = NULL) {
  stopifnot(is.character(key), is.character(label),
            is.function(fit), is.function(forecast), is.function(to_tibble))
  assign(key, list(
    key = key,
    label = label,
    fit = fit,
    forecast = forecast,
    to_tibble = to_tibble,
    supports_holidays = supports_holidays,
    requires = requires,
    annotate = annotate
  ), envir = .model_registry)
  invisible(TRUE)
}

get_model <- function(key) {
  if (!exists(key, envir = .model_registry, inherits = FALSE)) {
    stop("Unknown model: ", key, call. = FALSE)
  }
  get(key, envir = .model_registry, inherits = FALSE)
}

list_models <- function(available_only = TRUE) {
  keys <- ls(.model_registry)
  models <- lapply(keys, function(k) get(k, envir = .model_registry, inherits = FALSE))
  if (available_only) {
    models <- Filter(function(m) {
      is.null(m$requires) || requireNamespace(m$requires, quietly = TRUE)
    }, models)
  }
  models
}

# Shown in the UI whenever the selected model's `supports_holidays` is
# FALSE, mirroring the wording/style already used in the hosted app's ARIMA
# tab (ui/ui_tab4_arima.R).
holiday_limitation_note <- function(model_label) {
  paste0("ℹ️ ", model_label, " does not model holiday effects — results reflect that difference.")
}
