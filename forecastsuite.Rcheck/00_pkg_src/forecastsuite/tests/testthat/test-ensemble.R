test_that("ensemble_forecasts with method = 'mean' averages forecasts equally", {
  ds <- as.Date("2024-01-01") + 0:2
  forecasts <- list(
    A = tibble::tibble(ds = ds, yhat = c(10, 10, 10)),
    B = tibble::tibble(ds = ds, yhat = c(20, 20, 20))
  )
  ens <- ensemble_forecasts(forecasts, method = "mean")
  expect_equal(ens$yhat, c(15, 15, 15))
  expect_equal(ens$ds, ds)
})

test_that("ensemble_forecasts with method = 'inverse_error' weights the more accurate model more", {
  ds <- as.Date("2024-01-01") + 0:2
  forecasts <- list(
    A = tibble::tibble(ds = ds, yhat = c(10, 10, 10)),
    B = tibble::tibble(ds = ds, yhat = c(20, 20, 20))
  )
  # A has a much smaller error (RMSE = 1) than B (RMSE = 10) -> A dominates
  ens <- ensemble_forecasts(forecasts, method = "inverse_error", errors = list(A = 1, B = 10))
  expect_true(all(ens$yhat < 15))  # weighted result should sit much closer to A's 10 than the midpoint
  expect_true(all(ens$yhat > 10))
})

test_that("inverse_error falls back to equal weight for a missing/invalid error", {
  ds <- as.Date("2024-01-01") + 0:2
  forecasts <- list(
    A = tibble::tibble(ds = ds, yhat = c(10, 10, 10)),
    B = tibble::tibble(ds = ds, yhat = c(20, 20, 20))
  )
  ens <- ensemble_forecasts(forecasts, method = "inverse_error", errors = list(A = NA, B = 0))
  expect_equal(ens$yhat, c(15, 15, 15))  # both fall back to weight 1 -> simple average
})

test_that("ensemble_forecasts requires errors for inverse_error and errors on no forecasts", {
  ds <- as.Date("2024-01-01")
  forecasts <- list(A = tibble::tibble(ds = ds, yhat = 1))
  expect_error(ensemble_forecasts(forecasts, method = "inverse_error"), "errors")
  expect_error(ensemble_forecasts(list(A = NULL)), "No forecasts")
})

test_that("ensemble_forecasts handles models that don't share every ds via pairwise-present weighting", {
  forecasts <- list(
    A = tibble::tibble(ds = as.Date("2024-01-01") + 0:2, yhat = c(10, 10, 10)),
    B = tibble::tibble(ds = as.Date("2024-01-01") + 1:3, yhat = c(20, 20, 20))
  )
  ens <- ensemble_forecasts(forecasts, method = "mean")
  expect_equal(nrow(ens), 4)  # union of ds values
  # first day only has A -> should equal A's value, not a blended NA
  first_day <- ens$yhat[ens$ds == as.Date("2024-01-01")]
  expect_equal(first_day, 10)
})
