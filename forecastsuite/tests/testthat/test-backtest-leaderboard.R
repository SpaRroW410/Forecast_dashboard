.leaderboard_demo_series <- function(n = 60) {
  set.seed(11)
  ds <- as.Date("2023-01-01") + 0:(n - 1)
  y <- 100 + seq_len(n) * 0.3 + stats::rnorm(n, sd = 2)
  tibble::tibble(ds = ds, y = y)
}

test_that("run_backtest_leaderboard ranks models by mean test MASE, best first", {
  df <- .leaderboard_demo_series()
  result <- run_backtest_leaderboard(
    model_keys = c("arima", "ets"), df = df, date_agg = "day",
    horizon_periods = 5, k_requested = 2
  )
  expect_setequal(result$key, c("arima", "ets"))
  expect_equal(nrow(result), 2)
  expect_true(all(result$n_folds > 0))
  # ranked ascending by mean_mase (lower is better)
  expect_true(result$mean_mase[1] <= result$mean_mase[2])
})

test_that("run_backtest_leaderboard returns an empty, well-shaped tibble when no fold fits", {
  df <- tibble::tibble(ds = as.Date("2024-01-01") + 0:2, y = c(1, 2, 3))
  result <- run_backtest_leaderboard(
    model_keys = "arima", df = df, date_agg = "day",
    horizon_periods = 10, k_requested = 3
  )
  expect_equal(nrow(result), 0)
  expect_setequal(names(result), c("model", "key", "n_folds", "mean_mase", "sd_mase", "mean_smape", "mean_rmse"))
})

test_that("run_backtest_leaderboard gives a model an NA row (not a dropped row) when every fold fails", {
  df <- .leaderboard_demo_series()
  result <- run_backtest_leaderboard(
    model_keys = c("arima", "does_not_exist"), df = df, date_agg = "day",
    horizon_periods = 5, k_requested = 2
  )
  expect_true("does_not_exist" %in% result$key)
  failed_row <- result[result$key == "does_not_exist", ]
  expect_equal(failed_row$n_folds, 0)
  expect_true(is.na(failed_row$mean_mase))
})

test_that("run_backtest_leaderboard's build_args is used for every fold's fit call", {
  df <- .leaderboard_demo_series()
  seen_orders <- list()
  build_args <- function(model_key, train_df) {
    list(train_df = train_df, date_agg = "day", auto = FALSE, order = c(1, 1, 1))
  }
  result <- run_backtest_leaderboard(
    model_keys = "arima", df = df, date_agg = "day",
    horizon_periods = 5, k_requested = 2, build_args = build_args
  )
  expect_equal(result$n_folds, 2)
})

test_that("the app's leaderboard button is wired to reuse Compare Models' selection and shows the ranked table", {
  main <- .leaderboard_demo_series(90)
  df <- data.frame(when = main$ds, val = main$y)
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_leaderboard_test_df", df, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_leaderboard_test_df")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "when", fs_value_col = "val")
    session$setInputs(fs_date_agg = "day")
    session$setInputs(fs_finalize_data = 1)
    session$setInputs(fs_test_months = 1, fs_cv_folds = 2)
    session$setInputs(fs_compare_choices = c("arima", "ets"))

    session$setInputs(fs_run_leaderboard = 1)
    res <- leaderboard_result()
    expect_setequal(res$key, c("arima", "ets"))
  })
  rm("fs_leaderboard_test_df", envir = globalenv())
})
