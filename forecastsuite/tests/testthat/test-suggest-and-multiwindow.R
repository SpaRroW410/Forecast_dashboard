test_that("suggest_parameters proposes Prophet priors from measured strength", {
  strong <- list(trend_strength = 0.9, seasonal_strength = 0.8, ndiffs_needed = 1,
                  nsdiffs_needed = 1, detected_freq = 7, n_obs = 400, n_cycles = 57,
                  missing_ratio = 0)
  s <- suggest_parameters(strong, "prophet")
  expect_equal(s$params$cp, 0.15)
  expect_equal(s$params$season, 15)
  expect_match(s$text, "changepoint prior")

  flat <- modifyList(strong, list(trend_strength = 0.1, seasonal_strength = 0.05))
  f <- suggest_parameters(flat, "prophet")
  expect_equal(f$params$cp, 0.01)
  expect_equal(f$params$season, 3)
})

test_that("suggest_parameters grounds d and D in ndiffs/nsdiffs", {
  a <- list(trend_strength = 0.5, seasonal_strength = 0.6, ndiffs_needed = 2,
             nsdiffs_needed = 1, detected_freq = 12, n_obs = 200, n_cycles = 16,
             missing_ratio = 0)
  ar <- suggest_parameters(a, "arima")
  expect_equal(ar$params$order, c(1, 2, 1))
  expect_null(ar$params$seasonal_order)
  expect_match(ar$text, "ARIMA\\(1,2,1\\)")

  sa <- suggest_parameters(a, "sarima")
  expect_equal(sa$params$seasonal_order, c(1, 1, 0))
  expect_match(sa$text, "\\(1,1,0\\)\\[12\\]")
})

test_that("models without tunable parameters say so", {
  a <- list(trend_strength = .5, seasonal_strength = .5, ndiffs_needed = 1,
             nsdiffs_needed = 0, detected_freq = 7, n_obs = 100, n_cycles = 14,
             missing_ratio = 0)
  expect_match(suggest_parameters(a, "ets")$text, "fitted automatically")
  expect_equal(length(suggest_parameters_for(a, c("prophet", "arima", "ets"))), 3)
})

test_that("multi-window metrics report Train and the held-out window", {
  set.seed(4)
  n <- 400
  df <- tibble::tibble(ds = as.POSIXct(seq.Date(as.Date("2022-01-01"), by = "day", length.out = n)),
                        y = 100 + (1:n) * 0.05 + stats::rnorm(n, 0, 3))
  train <- df[1:350, ]; test <- df[351:400, ]
  fc <- tibble::tibble(ds = df$ds, yhat = df$y + stats::rnorm(n, 0, 1))

  m <- compute_multi_window_metrics(fc, train, test, "day")
  expect_true(all(c("Train", "Test (held out)") %in% m$Set))
  expect_true("Last 6 Months" %in% m$Set)   # 350-day train span supports it
  expect_false(any(is.na(m$Value)))
})

test_that("windows longer than the series are skipped rather than reported as NA", {
  set.seed(4)
  n <- 40
  df <- tibble::tibble(ds = as.POSIXct(seq.Date(as.Date("2024-01-01"), by = "day", length.out = n)),
                        y = stats::rnorm(n, 50, 5))
  train <- df[1:30, ]; test <- df[31:40, ]
  fc <- tibble::tibble(ds = df$ds, yhat = df$y)

  m <- compute_multi_window_metrics(fc, train, test, "day")
  expect_setequal(unique(m$Set), c("Train", "Test (held out)"))
  expect_false("Last 2 Years" %in% m$Set)
})
