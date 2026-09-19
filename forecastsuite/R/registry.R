# The pluggable model registry. Every model is registered as a small set of
# functions sharing one contract:
#   fit(train_df, date_agg, ...)       -> model_obj
#   forecast(model_obj, h, ...)        -> raw_forecast_obj
#   to_tibble(raw_forecast_obj, test_df) -> tibble(ds, yhat[, yhat_lower, yhat_upper])
#   annotate(model_obj) -> character(1)   [optional; e.g. "ARIMA(2,1,1)(1,0,0)[12]"]
#
# Adding a new model later is one file (following the model_*.R pattern)
# plus one register_model() call in zzz_register_builtins.R -- nothing else
# in the registry, UI, or metrics/plotting pipeline needs to change.

.model_registry <- new.env(parent = emptyenv())

#' Register a forecasting model
#'
#' Adds a model to the package's pluggable registry, keyed by `key`. Every
#' model implements the same three-function contract (`fit`/`forecast`/
#' `to_tibble`), so once registered it works everywhere in the bundled app
#' (Model tab, Compare Selected Models, Cross-Validation, the Backtest
#' Leaderboard, the Show Code panel) with no other code changes.
#'
#' @param key Character scalar, a unique registry key (e.g. `"arima"`).
#' @param label Character scalar, the human-readable name shown in the UI.
#' @param fit Function with signature `fit(train_df, date_agg, ...)`
#'   returning a fitted model object.
#' @param forecast Function with signature `forecast(model_obj, h, ...)`
#'   returning the model's raw forecast object.
#' @param to_tibble Function with signature
#'   `to_tibble(raw_forecast_obj, test_df)` returning a tibble with columns
#'   `ds`, `yhat`, and optionally `yhat_lower`/`yhat_upper`.
#' @param supports_holidays Logical; whether `fit()` accepts a
#'   `holidays_df` argument and models holiday effects. Default `FALSE`.
#' @param requires Character scalar naming an optional package this model
#'   needs (e.g. `"torch"`), or `NULL` if it has no extra dependency.
#'   `list_models(available_only = TRUE)` omits the model until that
#'   package is installed.
#' @param annotate Optional function with signature `annotate(model_obj)`
#'   returning a one-line character description of the fitted model (e.g.
#'   `"ARIMA(2,1,1)(1,0,0)[12]"`), shown as a plot subtitle.
#'
#' @return `TRUE`, invisibly.
#' @export
#' @examples
#' register_model(
#'   key = "naive_last",
#'   label = "Naive (last value)",
#'   fit = function(train_df, date_agg = "day", ...) utils::tail(train_df$y, 1),
#'   forecast = function(model_obj, h, ...) list(mean = rep(model_obj, h)),
#'   to_tibble = function(fc_obj, test_df) {
#'     tibble::tibble(ds = test_df$ds[seq_along(fc_obj$mean)], yhat = fc_obj$mean)
#'   }
#' )
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

#' Look up a registered model
#'
#' @param key Character scalar, the registry key (e.g. `"prophet"`,
#'   `"arima"`). See [list_models()] for every currently registered key.
#'
#' @return The registered model's list (`key`, `label`, `fit`, `forecast`,
#'   `to_tibble`, `supports_holidays`, `requires`, `annotate`).
#' @export
#' @examples
#' model <- get_model("arima")
#' model$label
get_model <- function(key) {
  if (!exists(key, envir = .model_registry, inherits = FALSE)) {
    stop("Unknown model: ", key, call. = FALSE)
  }
  get(key, envir = .model_registry, inherits = FALSE)
}

#' List every registered model
#'
#' @param available_only Logical; if `TRUE` (the default), omit any model
#'   whose `requires` package (see [register_model()]) isn't installed --
#'   e.g. `"lstm"` is omitted until `torch` is available.
#'
#' @return A list of registered model entries (see [get_model()] for the
#'   shape of each one).
#' @export
#' @examples
#' vapply(list_models(available_only = TRUE), function(m) m$key, character(1))
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

#' Holiday-limitation note for a model
#'
#' Shown in the UI whenever the selected model's `supports_holidays` is
#' `FALSE`, mirroring the wording/style already used in the hosted app's
#' ARIMA tab.
#'
#' @param model_label Character scalar, the model's display label.
#'
#' @return A one-line character string.
#' @export
#' @examples
#' holiday_limitation_note("ARIMA")
holiday_limitation_note <- function(model_label) {
  paste0("Note: ", model_label, " does not model holiday effects -- results reflect that difference.")
}
