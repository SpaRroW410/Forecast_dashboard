# Builds up to k_requested chronological, non-overlapping walk-forward
# folds from one ds-ordered series. Each fold's test window is exactly
# horizon_periods rows long, mirroring the app's train_test_split_for()
# cutoff logic but repeated at successively earlier points. Training
# windows always start from the beginning of the series (expanding
# window) rather than a fixed-length rolling window -- the simpler,
# more standard walk-forward interpretation.
#
# Degrades gracefully: if the series can't support k_requested folds
# (each needs horizon_periods more test rows than the fold before it,
# leaving at least min_train rows for training), fewer folds are
# returned instead of erroring -- possibly zero, for a very short
# series. Folds are returned oldest-first (fold 1 = smallest training
# window).
build_cv_folds <- function(df, horizon_periods, k_requested, min_train = 2) {
  df <- df[order(df$ds), ]
  n <- nrow(df)
  horizon_periods <- max(1L, as.integer(horizon_periods))
  k_requested <- max(1L, as.integer(k_requested))

  folds <- list()
  for (i in seq_len(k_requested)) {
    test_end   <- n - (i - 1L) * horizon_periods
    test_start <- test_end - horizon_periods + 1L
    train_end  <- test_start - 1L
    if (test_start < 1L || train_end < min_train) break
    folds[[length(folds) + 1L]] <- list(
      train = df[seq_len(train_end), , drop = FALSE],
      test  = df[test_start:test_end, , drop = FALSE]
    )
  }
  rev(folds)
}
