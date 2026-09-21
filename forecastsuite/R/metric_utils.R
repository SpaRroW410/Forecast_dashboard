# Adapted from the parent repo's helpers/metric_utils.R -- identical logic,
# package-namespaced. See this package's README for why it's a copy rather
# than a shared source.

#' Compute MASE, sMAPE, and RMSE for a forecast
#'
#' @param actual_df A tibble with `ds`/`y` columns -- the held-out actuals.
#' @param forecast_df A tibble with `ds`/`yhat` columns -- the forecast to
#'   evaluate.
#' @param label Character scalar identifying this evaluation (shown as the
#'   `Set` column), e.g. `"Test"`.
#'
#' @return A tibble with columns `Set`, `Metric` (`"MASE"`, `"sMAPE (%)"`,
#'   `"RMSE"`), and `Value` -- `NA` for all three if fewer than 2 rows
#'   overlap.
#' @export
#' @examples
#' ds <- as.Date("2024-01-01") + 0:9
#' actual_df <- tibble::tibble(ds = ds, y = 1:10)
#' forecast_df <- tibble::tibble(ds = ds, yhat = 1:10 + 0.5)
#' compute_forecast_metrics(actual_df, forecast_df, label = "Test")
compute_forecast_metrics <- function(actual_df, forecast_df, label = "Test") {
  joined <- dplyr::inner_join(forecast_df, actual_df, by = "ds")

  if (nrow(joined) < 2) {
    return(tibble::tibble(Set = label, Metric = c("MASE", "sMAPE (%)", "RMSE"), Value = NA))
  }

  mae_naive <- mean(abs(diff(actual_df$y)), na.rm = TRUE)
  mae_model <- mean(abs(joined$y - joined$yhat), na.rm = TRUE)
  mase <- mae_model / mae_naive

  smape <- mean(2 * abs(joined$y - joined$yhat) /
                  (abs(joined$y) + abs(joined$yhat)), na.rm = TRUE) * 100

  rmse <- sqrt(mean((joined$y - joined$yhat)^2, na.rm = TRUE))

  tibble::tibble(
    Set = label,
    Metric = c("MASE", "sMAPE (%)", "RMSE"),
    Value = round(c(mase, smape, rmse), 3)
  )
}

#' Compute forecast metrics, guarding against a too-short test set
#'
#' Same as [compute_forecast_metrics()], but checks `actual_df`'s row count
#' first so callers don't need their own length guard before calling it.
#'
#' @param forecast_df A tibble with `ds`/`yhat` columns.
#' @param actual_df A tibble with `ds`/`y` columns.
#' @param label Character scalar identifying this evaluation.
#'
#' @return A tibble with columns `Set`, `Metric`, `Value` (see
#'   [compute_forecast_metrics()]).
#' @export
#' @examples
#' ds <- as.Date("2024-01-01") + 0:9
#' forecast_df <- tibble::tibble(ds = ds, yhat = 1:10 + 0.5)
#' actual_df <- tibble::tibble(ds = ds, y = 1:10)
#' safe_compute_metrics(forecast_df, actual_df, label = "Test")
safe_compute_metrics <- function(forecast_df, actual_df, label) {
  if (nrow(actual_df) < 2) {
    return(tibble::tibble(Set = label, Metric = c("MASE", "sMAPE (%)", "RMSE"), Value = NA))
  }
  compute_forecast_metrics(actual_df, forecast_df, label = label)
}
