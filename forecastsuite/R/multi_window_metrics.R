# Scoring a forecast over several windows at once, ported from the hosted
# app's evaluation table (server/server_forecast.R), which reported Train /
# Last 6 Months / Last 2 Years / Manual Entry rather than a single number.
#
# The point is that one aggregate score hides where a model actually fails:
# a model can look strong on the full training range while drifting badly
# over the most recent months, which is usually the part you care about.
#
# Windows are skipped rather than reported as NA when the series is too
# short to contain them, so a two-year dataset does not produce a mostly
# empty table.

#' Score a forecast over several evaluation windows at once
#'
#' A single aggregate score hides where a model actually fails -- it can
#' look strong on the full training range while drifting badly over the
#' most recent months. Scores Train / Last 6 Months / Last 2 Years / Test
#' (held out) using [safe_compute_metrics()], skipping windows the series
#' is too short to contain rather than reporting them as `NA`.
#'
#' @param forecast_df A tibble with `ds`/`yhat` columns.
#' @param train_df A tibble with `ds`/`y` columns -- the training data.
#' @param test_df A tibble with `ds`/`y` columns -- the held-out test data.
#' @param date_agg Aggregation frequency (currently unused directly, kept
#'   for interface consistency with the rest of the package).
#'
#' @return A tibble with columns `Set`, `Metric`, `Value` -- one block per
#'   window that applied.
#' @export
#' @examples
#' ds <- as.Date("2024-01-01") + 0:29
#' train_df <- tibble::tibble(ds = ds[1:20], y = 1:20)
#' test_df <- tibble::tibble(ds = ds[21:30], y = 21:30)
#' forecast_df <- tibble::tibble(ds = ds, yhat = 1:30 + 0.5)
#' compute_multi_window_metrics(forecast_df, train_df, test_df)
compute_multi_window_metrics <- function(forecast_df, train_df, test_df,
                                          date_agg = "day") {
  windows <- list()

  if (!is.null(train_df) && nrow(train_df) >= 2) {
    windows[["Train"]] <- train_df

    span_days <- as.numeric(difftime(max(train_df$ds), min(train_df$ds), units = "days"))
    recent <- function(months) {
      # ds may be Date (arithmetic in days) or POSIXct (seconds); an
      # explicit difftime in days is correct for both, whereas subtracting
      # a bare number silently means days for one and seconds for the other.
      cutoff <- max(train_df$ds) - as.difftime(months * 30.44, units = "days")
      subset <- train_df[train_df$ds > cutoff, ]
      if (nrow(subset) >= 2 && nrow(subset) < nrow(train_df)) subset else NULL
    }

    # Only offer a shorter window when the series is meaningfully longer
    # than it, otherwise it just restates Train.
    if (span_days > 200)  windows[["Last 6 Months"]] <- recent(6)
    if (span_days > 800)  windows[["Last 2 Years"]]  <- recent(24)
  }

  if (!is.null(test_df) && nrow(test_df) >= 2) {
    windows[["Test (held out)"]] <- test_df
  }

  windows <- windows[!vapply(windows, is.null, logical(1))]
  if (!length(windows)) {
    return(tibble::tibble(Set = character(), Metric = character(), Value = numeric()))
  }

  dplyr::bind_rows(lapply(names(windows), function(nm) {
    safe_compute_metrics(forecast_df, windows[[nm]], label = nm)
  }))
}
