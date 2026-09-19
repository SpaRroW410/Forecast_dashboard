test_that("compute_forecast_bias reports the correct signed mean error", {
  ds <- as.Date("2024-01-01") + 0:4
  test_df <- tibble::tibble(ds = ds, y = c(10, 10, 10, 10, 10))
  fc_tib <- tibble::tibble(ds = ds, yhat = c(8, 8, 8, 8, 8))  # consistently under-forecasting

  b <- compute_forecast_bias(fc_tib, test_df)
  expect_equal(b$bias, 2)          # y - yhat = 10 - 8
  expect_equal(b$pct_bias, 20)     # 2 / mean(|y|) * 100 = 2/10*100
  expect_equal(b$n, 5)
})

test_that("compute_forecast_bias handles zero overlap without erroring", {
  fc_tib <- tibble::tibble(ds = as.Date("2024-01-01"), yhat = 1)
  test_df <- tibble::tibble(ds = as.Date("2024-06-01"), y = 1)
  b <- compute_forecast_bias(fc_tib, test_df)
  expect_equal(b$n, 0)
  expect_true(is.na(b$bias))
  expect_true(is.na(b$pct_bias))
})

test_that("detect_bias_drift splits the window into chunks and flags growing |bias|", {
  ds <- as.Date("2024-01-01") + 0:9
  test_df <- tibble::tibble(ds = ds, y = rep(10, 10))
  # first half: no bias; second half: growing under-forecast
  fc_tib <- tibble::tibble(ds = ds, yhat = c(rep(10, 5), rep(6, 5)))

  bd <- detect_bias_drift(fc_tib, test_df, n_splits = 2)
  expect_equal(nrow(bd$chunks), 2)
  expect_equal(bd$chunks$chunk, c(1, 2))
  expect_equal(bd$chunks$bias[1], 0)
  expect_equal(bd$chunks$bias[2], 4)
  expect_true(isTRUE(bd$drifting))
})

test_that("detect_bias_drift reports no drift for a stable bias", {
  ds <- as.Date("2024-01-01") + 0:9
  test_df <- tibble::tibble(ds = ds, y = rep(10, 10))
  fc_tib <- tibble::tibble(ds = ds, yhat = rep(8, 10))  # constant 2-unit bias throughout

  bd <- detect_bias_drift(fc_tib, test_df, n_splits = 2)
  expect_false(isTRUE(bd$drifting))
})

test_that("detect_bias_drift degrades gracefully on a short window (fewer chunks, or NA drift)", {
  ds <- as.Date("2024-01-01")
  test_df <- tibble::tibble(ds = ds, y = 10)
  fc_tib <- tibble::tibble(ds = ds, yhat = 9)

  bd <- detect_bias_drift(fc_tib, test_df, n_splits = 5)  # only 1 row available
  expect_equal(nrow(bd$chunks), 1)
  expect_true(is.na(bd$drifting))
})

test_that("detect_bias_drift handles zero overlap without erroring", {
  fc_tib <- tibble::tibble(ds = as.Date("2024-01-01"), yhat = 1)
  test_df <- tibble::tibble(ds = as.Date("2024-06-01"), y = 1)
  bd <- detect_bias_drift(fc_tib, test_df)
  expect_equal(nrow(bd$chunks), 0)
  expect_true(is.na(bd$drifting))
})
