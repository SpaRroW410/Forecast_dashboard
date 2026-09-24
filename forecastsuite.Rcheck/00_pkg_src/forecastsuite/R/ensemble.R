# Combines several already-fit models' forecasts into one -- the same
# named-list-of-ds/yhat-tibbles shape plot_model_comparison() already
# consumes from "Compare Selected Models", so no extra fitting is needed
# here. Often beats any single model in the comparison; a natural extension
# of the reconciliation/comparison work already in the package.

#' Combine several models' forecasts into one
#'
#' Averages (simple or inverse-error-weighted) several already-fit models'
#' forecasts -- no re-fitting. Models that don't share every `ds` are
#' handled by renormalizing weights per-row over whichever models actually
#' have a value there.
#'
#' @param forecasts A named list of `ds`/`yhat` tibbles (names are the model
#'   labels).
#' @param method `"mean"` (the default) weights every model equally;
#'   `"inverse_error"` weights each model by `1/errors[[name]]`. A model
#'   missing from `errors`, or with a non-positive/`NA` error, falls back to
#'   equal weight rather than dividing by zero.
#' @param errors Required for `method = "inverse_error"`: a named list or
#'   vector of each model's own test error (e.g. RMSE or MASE, from
#'   [safe_compute_metrics()] -- not re-derived here), keyed by the same
#'   names as `forecasts`.
#'
#' @return A tibble with columns `ds` and `yhat` -- the combined forecast.
#' @export
#' @examples
#' ds <- as.Date("2024-01-01") + 0:2
#' forecasts <- list(
#'   A = tibble::tibble(ds = ds, yhat = c(10, 10, 10)),
#'   B = tibble::tibble(ds = ds, yhat = c(20, 20, 20))
#' )
#' ensemble_forecasts(forecasts, method = "mean")
#' ensemble_forecasts(forecasts, method = "inverse_error", errors = list(A = 1, B = 5))
ensemble_forecasts <- function(forecasts, method = c("mean", "inverse_error"), errors = NULL) {
  method <- match.arg(method)
  forecasts <- forecasts[!vapply(forecasts, is.null, logical(1))]
  if (!length(forecasts)) stop("No forecasts to ensemble.", call. = FALSE)

  model_names <- names(forecasts)
  long <- dplyr::bind_rows(lapply(model_names, function(nm) {
    tibble::tibble(ds = forecasts[[nm]]$ds, yhat = forecasts[[nm]]$yhat, model = nm)
  }))
  wide <- tidyr::pivot_wider(long, names_from = "model", values_from = "yhat")

  weights <- if (method == "mean") {
    stats::setNames(rep(1, length(model_names)), model_names)
  } else {
    if (is.null(errors)) stop("`errors` is required for method = \"inverse_error\".", call. = FALSE)
    vapply(model_names, function(nm) {
      e <- errors[[nm]]
      if (is.null(e) || is.na(e) || e <= 0) 1 else 1 / e
    }, numeric(1))
  }
  weights <- weights / sum(weights)

  yhat_mat <- as.matrix(wide[, model_names, drop = FALSE])
  combined <- apply(yhat_mat, 1, function(row) {
    present <- !is.na(row)
    if (!any(present)) return(NA_real_)
    w <- weights[present]
    sum(row[present] * w) / sum(w)
  })

  tibble::tibble(ds = wide$ds, yhat = as.numeric(combined))
}
