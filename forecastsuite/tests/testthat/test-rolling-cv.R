test_that("build_cv_folds produces chronological, non-overlapping, expanding-window folds", {
  df <- data.frame(ds = as.Date("2020-01-01") + 0:99, y = 1:100)
  folds <- build_cv_folds(df, horizon_periods = 6, k_requested = 3)
  expect_equal(length(folds), 3)
  for (f in folds) expect_equal(nrow(f$test), 6)
  train_sizes <- vapply(folds, function(f) nrow(f$train), integer(1))
  expect_true(all(diff(train_sizes) > 0))  # strictly increasing training windows
  # non-overlapping, chronological: each fold's test starts right after
  # the previous fold's test ends
  for (i in 2:length(folds)) {
    expect_equal(min(folds[[i]]$test$ds), max(folds[[i - 1]]$test$ds) + 1)
  }
  # every fold's training window starts at the very beginning (expanding, not rolling)
  for (f in folds) expect_equal(min(f$train$ds), min(df$ds))
})

test_that("build_cv_folds degrades to fewer folds than requested rather than erroring", {
  df <- data.frame(ds = as.Date("2020-01-01") + 0:20, y = 1:21)
  folds <- build_cv_folds(df, horizon_periods = 6, k_requested = 5)
  expect_lt(length(folds), 5)
  expect_gt(length(folds), 0)
})

test_that("build_cv_folds returns zero folds for a series too short for even one", {
  df <- data.frame(ds = as.Date("2020-01-01") + 0:2, y = 1:3)
  folds <- build_cv_folds(df, horizon_periods = 6, k_requested = 3)
  expect_equal(length(folds), 0)
})

.cv_demo_series <- function(n = 400) {
  set.seed(1)
  data.frame(
    date = seq.Date(as.Date("2019-01-01"), by = "day", length.out = n),
    value = 100 + 0.05 * (1:n) + 10 * sin(2 * pi * (1:n) / 7) + stats::rnorm(n, sd = 3)
  )
}

test_that("Run Cross-Validation produces fold rows plus a Mean/SD summary matching manual aggregation", {
  df <- .cv_demo_series()
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_cv_test_df", df, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_cv_test_df")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "date", fs_value_col = "value")
    session$setInputs(fs_date_agg = "day")
    session$setInputs(fs_finalize_data = 1)
    session$setInputs(fs_model_choice = "arima", fs_arima_mode = "auto")
    session$setInputs(fs_horizon_months = 3, fs_test_months = 1)
    session$setInputs(fs_cv_folds = 3)
    session$setInputs(fs_run_cv = 1)

    res <- cv_result()
    expect_setequal(unique(res$Set), c("Fold 1", "Fold 2", "Fold 3", "Mean", "SD"))

    wide <- tidyr::pivot_wider(res, names_from = "Metric", values_from = "Value")
    fold_mase <- wide$MASE[wide$Set %in% c("Fold 1", "Fold 2", "Fold 3")]
    expect_equal(wide$MASE[wide$Set == "Mean"], mean(fold_mase))
    expect_equal(wide$MASE[wide$Set == "SD"], stats::sd(fold_mase))
  })
  rm("fs_cv_test_df", envir = globalenv())
})

test_that("requesting more folds than the series supports degrades gracefully end to end", {
  df <- .cv_demo_series(n = 40)
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_cv_short_df", df, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_cv_short_df")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "date", fs_value_col = "value")
    session$setInputs(fs_date_agg = "day")
    session$setInputs(fs_finalize_data = 1)
    session$setInputs(fs_model_choice = "arima", fs_arima_mode = "auto")
    session$setInputs(fs_horizon_months = 1, fs_test_months = 1)
    session$setInputs(fs_cv_folds = 20)
    session$setInputs(fs_run_cv = 1)

    res <- cv_result()
    expect_false(is.null(res))
    n_folds <- sum(grepl("^Fold ", unique(res$Set)))
    expect_lt(n_folds, 20)
    expect_gt(n_folds, 0)
  })
  rm("fs_cv_short_df", envir = globalenv())
})

test_that("cross-validation is scoped to the currently-viewed series and never multiplies across groups", {
  set.seed(1)
  main <- data.frame(
    Date = rep(seq.Date(as.Date("2020-01-01"), as.Date("2021-12-31"), by = "day"), 2),
    District = rep(c("A", "B"), each = 731),
    Cases = c(stats::rpois(731, 20), stats::rpois(731, 10))
  )
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_cv_grp_test_df", main, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_cv_grp_test_df")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "Date", fs_value_col = "Cases")
    session$setInputs(fs_date_agg = "day")
    session$setInputs(fs_group_col = "District")
    session$setInputs(fs_group_values = c("A", "B"))
    session$setInputs(fs_finalize_data = 1)
    session$setInputs(fs_model_choice = "ets")
    session$setInputs(fs_horizon_months = 1, fs_test_months = 1)
    session$setInputs(fs_fit_groups = c("A", "B"))
    session$setInputs(fs_fit_btn = 1)
    session$setInputs(fs_group_view = "B")

    session$setInputs(fs_cv_folds = 2)
    session$setInputs(fs_run_cv = 1)
    res <- cv_result()
    n_folds <- sum(grepl("^Fold ", unique(res$Set)))
    expect_equal(n_folds, 2)  # exactly 2, never 2 x number of groups
  })
  rm("fs_cv_grp_test_df", envir = globalenv())
})
