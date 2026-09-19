# Bias/drift tracking: MASE/sMAPE/RMSE (metric_utils.R) are all
# magnitude-only, so a model that's consistently over- or under-forecasting
# by a wide margin can still look "fine" on those alone. This surfaces the
# signed error directly, and whether it's growing across the test window.

#' Signed forecast error (bias)
#'
#' MASE/sMAPE/RMSE are all magnitude-only, so a model that's consistently
#' over- or under-forecasting can still look "fine" on those alone. This
#' surfaces the signed error directly. Generic across every registered
#' model -- only needs `fc_tib`'s `ds`/`yhat` and `test_df`'s `ds`/`y`.
#'
#' @param fc_tib A tibble with `ds`/`yhat` columns -- a model's forecast.
#' @param test_df A tibble with `ds`/`y` columns -- the held-out actuals.
#'
#' @return A list with `bias` (mean signed error, `y - yhat`), `pct_bias`
#'   (`bias` as a percentage of mean `|y|`), and `n`. All `NA`/`0` if there's
#'   no overlap.
#' @export
#' @examples
#' ds <- as.Date("2024-01-01") + 0:4
#' fc_tib <- tibble::tibble(ds = ds, yhat = rep(8, 5))
#' test_df <- tibble::tibble(ds = ds, y = rep(10, 5))
#' compute_forecast_bias(fc_tib, test_df)
compute_forecast_bias <- function(fc_tib, test_df) {
  joined <- dplyr::inner_join(fc_tib, test_df, by = "ds")
  if (nrow(joined) == 0) {
    return(list(bias = NA_real_, pct_bias = NA_real_, n = 0L))
  }
  bias <- mean(joined$y - joined$yhat, na.rm = TRUE)
  denom <- mean(abs(joined$y), na.rm = TRUE)
  pct_bias <- if (is.finite(denom) && denom > 0) bias / denom * 100 else NA_real_
  list(bias = bias, pct_bias = pct_bias, n = nrow(joined))
}

#' Check whether forecast bias is growing across the test window
#'
#' Splits the test window into `n_splits` sequential, roughly-equal chunks
#' (oldest first) and computes [compute_forecast_bias()] in each -- a
#' simple, explainable drift signal (is `|bias|` growing chunk over chunk),
#' not a full statistical trend test.
#'
#' @param fc_tib A tibble with `ds`/`yhat` columns -- a model's forecast.
#' @param test_df A tibble with `ds`/`y` columns -- the held-out actuals.
#' @param n_splits Integer, how many sequential chunks to split the window
#'   into. Default `2`. Capped so every chunk gets at least one row rather
#'   than erroring on a short window.
#'
#' @return A list with `chunks` (a tibble of `chunk`/`bias`/`pct_bias`/`n`,
#'   one row per chunk) and `drifting` (`TRUE` if `|bias|` strictly
#'   increases chunk over chunk, `FALSE` if not, `NA` if there isn't enough
#'   data for a read).
#' @export
#' @examples
#' ds <- as.Date("2024-01-01") + 0:9
#' fc_tib <- tibble::tibble(ds = ds, yhat = c(rep(10, 5), rep(6, 5)))
#' test_df <- tibble::tibble(ds = ds, y = rep(10, 10))
#' detect_bias_drift(fc_tib, test_df, n_splits = 2)
detect_bias_drift <- function(fc_tib, test_df, n_splits = 2) {
  joined <- dplyr::inner_join(fc_tib, test_df, by = "ds")
  joined <- joined[order(joined$ds), ]
  n <- nrow(joined)

  empty <- tibble::tibble(chunk = integer(), bias = double(), pct_bias = double(), n = integer())
  if (n == 0) return(list(chunks = empty, drifting = NA))

  n_splits <- max(1L, min(as.integer(n_splits), n))
  chunk_idx <- cut(seq_len(n), breaks = n_splits, labels = FALSE)

  rows <- lapply(seq_len(n_splits), function(i) {
    sub <- joined[chunk_idx == i, , drop = FALSE]
    if (nrow(sub) == 0) return(tibble::tibble(chunk = i, bias = NA_real_, pct_bias = NA_real_, n = 0L))
    b <- mean(sub$y - sub$yhat, na.rm = TRUE)
    denom <- mean(abs(sub$y), na.rm = TRUE)
    pct <- if (is.finite(denom) && denom > 0) b / denom * 100 else NA_real_
    tibble::tibble(chunk = i, bias = b, pct_bias = pct, n = nrow(sub))
  })
  chunks <- dplyr::bind_rows(rows)

  valid <- chunks$bias[!is.na(chunks$bias)]
  drifting <- if (length(valid) >= 2) all(diff(abs(valid)) > 0) else NA

  list(chunks = chunks, drifting = drifting)
}
