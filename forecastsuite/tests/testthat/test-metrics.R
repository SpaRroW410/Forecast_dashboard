test_that("process_uploaded_data produces a clean ds/y tibble", {
  raw <- data.frame(date = seq.Date(as.Date("2023-01-01"), by = "day", length.out = 30),
                     value = rnorm(30, 50, 5))
  out <- process_uploaded_data(raw, type = "agg", date_col = "date", value_col = "value", date_agg = "day")
  expect_true(all(c("ds", "y") %in% names(out)))
  expect_equal(nrow(out), 30)
  expect_s3_class(out$ds, "POSIXt")
})

test_that("process_uploaded_data errors clearly on a missing column", {
  raw <- data.frame(date = Sys.Date() - 1:10, value = rnorm(10))
  expect_error(
    process_uploaded_data(raw, type = "agg", date_col = "nope", value_col = "value", date_agg = "day"),
    "not found"
  )
})

test_that("safe_compute_metrics returns NA rows instead of erroring on too little test data", {
  forecast_df <- tibble::tibble(ds = Sys.Date() + 1:5, yhat = rnorm(5))
  actual_df <- tibble::tibble(ds = Sys.Date() + 1, y = 1)
  m <- safe_compute_metrics(forecast_df, actual_df, "Test")
  expect_true(all(is.na(m$Value)))
})

test_that("safe_compute_metrics computes real metrics with enough overlap", {
  ds <- Sys.Date() + 1:10
  forecast_df <- tibble::tibble(ds = ds, yhat = 1:10)
  actual_df <- tibble::tibble(ds = ds, y = 1:10 + rnorm(10, 0, 0.01))
  m <- safe_compute_metrics(forecast_df, actual_df, "Test")
  expect_false(any(is.na(m$Value)))
  expect_true(all(c("MASE", "sMAPE (%)", "RMSE") %in% m$Metric))
})

test_that("convert_months_to_horizon matches the documented conversions", {
  expect_equal(convert_months_to_horizon(2, "day"), 60)
  expect_equal(convert_months_to_horizon(1, "week"), ceiling(30 / 7))
  expect_equal(convert_months_to_horizon(5, "month"), 5)
  expect_error(convert_months_to_horizon(1, "year"), "Unsupported")
})

test_that("ts_frequency_for maps date_agg to sensible ts() frequencies", {
  expect_equal(ts_frequency_for("day"), 365)
  expect_equal(ts_frequency_for("week"), 52)
  expect_equal(ts_frequency_for("month"), 12)
  expect_equal(ts_frequency_for("hour"), 24)
  expect_equal(ts_frequency_for("nonsense"), ts_frequency_for("day"))
})
