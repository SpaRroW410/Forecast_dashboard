#' Build rolling-origin (walk-forward) cross-validation folds
#'
#' Builds up to `k_requested` chronological, non-overlapping walk-forward
#' folds from one `ds`-ordered series. Each fold's test window is exactly
#' `horizon_periods` rows long. Degrades gracefully: if the series can't
#' support `k_requested` folds, fewer are returned instead of erroring --
#' possibly zero, for a very short series.
#'
#' @param df A data frame with a `ds` column, in any row order (it's sorted
#'   internally).
#' @param horizon_periods Integer, the length of each fold's test window,
#'   in the same units as `df$ds`'s spacing.
#' @param k_requested Integer, the number of folds requested (may return
#'   fewer).
#' @param min_train Integer, the minimum number of training rows a fold
#'   must have to be included. Default `2`.
#' @param window `"expanding"` (the default -- training windows always
#'   start from the beginning of the series, growing fold over fold) or
#'   `"rolling"` (each fold's training window is capped to the most recent
#'   `train_window` rows instead, a fixed width -- useful for testing
#'   robustness to concept drift/regime change separately from an
#'   ever-larger training set).
#' @param train_window Integer, the fixed training-window width used when
#'   `window = "rolling"`. Ignored for `"expanding"`. Defaults to `NULL`,
#'   which uses what would be the smallest (earliest) fold's expanding
#'   training size -- a sensible width with no extra input needed.
#'
#' @return A list of folds, oldest-first (fold 1 has the smallest training
#'   window under `"expanding"`, or the same fixed width under
#'   `"rolling"`), each a list with `train` and `test` data frames.
#' @export
#' @examples
#' df <- data.frame(ds = as.Date("2024-01-01") + 0:29, y = 1:30)
#' folds <- build_cv_folds(df, horizon_periods = 5, k_requested = 3)
#' length(folds)
#' rolling_folds <- build_cv_folds(df, horizon_periods = 5, k_requested = 3,
#'                                  window = "rolling", train_window = 10)
#' length(rolling_folds)
build_cv_folds <- function(df, horizon_periods, k_requested, min_train = 2,
                            window = c("expanding", "rolling"), train_window = NULL) {
  window <- match.arg(window)
  df <- df[order(df$ds), ]
  n <- nrow(df)
  horizon_periods <- max(1L, as.integer(horizon_periods))
  k_requested <- max(1L, as.integer(k_requested))

  if (window == "rolling" && is.null(train_window)) {
    # Default to what would be the smallest (earliest) expanding fold's
    # training size, so "no extra input" still produces a sensible, fixed
    # width rather than an arbitrary one.
    smallest_train_end <- (n - (k_requested - 1L) * horizon_periods) - horizon_periods
    train_window <- max(min_train, smallest_train_end)
  }

  folds <- list()
  for (i in seq_len(k_requested)) {
    test_end   <- n - (i - 1L) * horizon_periods
    test_start <- test_end - horizon_periods + 1L
    train_end  <- test_start - 1L
    if (test_start < 1L || train_end < min_train) break

    train_start <- if (window == "rolling") max(1L, train_end - as.integer(train_window) + 1L) else 1L

    folds[[length(folds) + 1L]] <- list(
      train = df[train_start:train_end, , drop = FALSE],
      test  = df[test_start:test_end, , drop = FALSE]
    )
  }
  rev(folds)
}

#' Multi-model rolling-origin backtest leaderboard
#'
#' Runs [build_cv_folds()] once and refits every model in `model_keys`
#' across every fold, ranking them by mean test MASE -- a real multi-model
#' extension of single-model cross-validation. A fold a model fails on is
#' dropped for that model rather than failing the whole row; a model with
#' zero successful folds (including an invalid `model_keys` entry) gets an
#' `NA` row instead of being dropped, so it's still visible in the result as
#' "failed."
#'
#' @param model_keys Character vector of registry keys (see
#'   [list_models()]) to include in the leaderboard.
#' @param df A data frame with `ds`/`y` columns -- the series to backtest.
#' @param date_agg Aggregation frequency (e.g. `"day"`, `"month"`), passed
#'   through to each model's `fit()`.
#' @param horizon_periods Integer, each fold's test window length (see
#'   [build_cv_folds()]).
#' @param k_requested Integer, the number of folds requested (may return
#'   fewer; see [build_cv_folds()]).
#' @param build_args A function `function(model_key, train_df)` returning
#'   the full argument list for that model's `fit()` call (`train_df`/
#'   `date_agg` included). The default passes `train_df`/`date_agg` through
#'   with no model-specific tuning; callers wanting each model's
#'   currently-configured parameters (e.g. the bundled app, which passes
#'   its own `build_fit_args()`) can supply their own.
#' @param window `"expanding"` (the default) or `"rolling"`, passed through
#'   to [build_cv_folds()] -- see there for what each means.
#' @param train_window Integer or `NULL`, passed through to
#'   [build_cv_folds()] when `window = "rolling"`.
#'
#' @return A tibble with one row per model in `model_keys`, columns `model`
#'   (label), `key`, `n_folds`, `mean_mase`, `sd_mase`, `mean_smape`,
#'   `mean_rmse`, ranked ascending by `mean_mase` (`NA` last).
#' @export
#' @examples
#' df <- data.frame(ds = as.Date("2024-01-01") + 0:59,
#'                   y = 100 + seq_len(60) * 0.2 + stats::rnorm(60, sd = 2))
#' \donttest{
#' run_backtest_leaderboard(c("arima", "ets"), df, date_agg = "day",
#'                           horizon_periods = 5, k_requested = 2)
#' }
run_backtest_leaderboard <- function(model_keys, df, date_agg, horizon_periods, k_requested,
                                      build_args = function(model_key, train_df) {
                                        list(train_df = train_df, date_agg = date_agg)
                                      },
                                      window = c("expanding", "rolling"), train_window = NULL) {
  window <- match.arg(window)
  empty <- tibble::tibble(model = character(), key = character(), n_folds = integer(),
                           mean_mase = double(), sd_mase = double(),
                           mean_smape = double(), mean_rmse = double())

  folds <- build_cv_folds(df, horizon_periods, k_requested, window = window, train_window = train_window)
  if (length(folds) == 0) return(empty)

  rows <- lapply(model_keys, function(key) {
    entry <- tryCatch(get_model(key), error = function(e) NULL)
    if (is.null(entry)) {
      return(tibble::tibble(model = key, key = key, n_folds = 0L,
                             mean_mase = NA_real_, sd_mase = NA_real_,
                             mean_smape = NA_real_, mean_rmse = NA_real_))
    }
    fold_metrics <- lapply(folds, function(f) {
      tryCatch({
        model_obj <- do.call(entry$fit, build_args(key, f$train))
        fc_raw <- entry$forecast(model_obj, horizon_periods)
        fc_tib <- entry$to_tibble(fc_raw, f$test)
        safe_compute_metrics(fc_tib, f$test, label = entry$label)
      }, error = function(e) NULL)
    })
    fold_metrics <- fold_metrics[!vapply(fold_metrics, is.null, logical(1))]

    if (!length(fold_metrics)) {
      return(tibble::tibble(model = entry$label, key = key, n_folds = 0L,
                             mean_mase = NA_real_, sd_mase = NA_real_,
                             mean_smape = NA_real_, mean_rmse = NA_real_))
    }

    long <- dplyr::bind_rows(fold_metrics)
    stat_for <- function(metric, fn) {
      v <- long$Value[long$Metric == metric]
      if (!length(v)) NA_real_ else fn(v, na.rm = TRUE)
    }
    tibble::tibble(
      model = entry$label, key = key, n_folds = length(fold_metrics),
      mean_mase = stat_for("MASE", mean), sd_mase = stat_for("MASE", stats::sd),
      mean_smape = stat_for("sMAPE (%)", mean), mean_rmse = stat_for("RMSE", mean)
    )
  })

  result <- dplyr::bind_rows(rows)
  result[order(result$mean_mase, na.last = TRUE), ]
}
