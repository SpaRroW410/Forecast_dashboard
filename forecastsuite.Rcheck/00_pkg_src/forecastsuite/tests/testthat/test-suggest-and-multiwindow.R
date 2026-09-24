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

test_that("suggest_parameters grounds d and D in ndiffs/nsdiffs, and p/q/P/Q in analyze_series' ACF/PACF fields", {
  a <- list(trend_strength = 0.5, seasonal_strength = 0.6, ndiffs_needed = 2,
             nsdiffs_needed = 1, detected_freq = 12, n_obs = 200, n_cycles = 16,
             missing_ratio = 0, arima_p = 2L, arima_q = 1L, arima_P = 1L, arima_Q = 0L)
  ar <- suggest_parameters(a, "arima")
  expect_equal(ar$params$order, c(2, 2, 1))
  expect_null(ar$params$seasonal_order)
  expect_match(ar$text, "ARIMA\\(2,2,1\\)")
  expect_match(paste(ar$reasons, collapse = " "), "p = 2, q = 1")

  sa <- suggest_parameters(a, "sarima")
  expect_equal(sa$params$seasonal_order, c(1, 1, 0))
  expect_match(sa$text, "\\(1,1,0\\)\\[12\\]")
  expect_match(paste(sa$reasons, collapse = " "), "P = 1, Q = 0")
})

test_that("suggest_parameters falls back to p=1,q=1,P=0,Q=0 when analyze_series' fields are absent", {
  # analyze_series() always supplies these now, but suggest_parameters()
  # should still degrade gracefully for a hand-built analysis list.
  a <- list(trend_strength = 0.5, seasonal_strength = 0.6, ndiffs_needed = 2,
             nsdiffs_needed = 1, detected_freq = 12, n_obs = 200, n_cycles = 16,
             missing_ratio = 0)
  ar <- suggest_parameters(a, "arima")
  expect_equal(ar$params$order, c(1, 2, 1))
  sa <- suggest_parameters(a, "sarima")
  expect_equal(sa$params$seasonal_order, c(0, 1, 0))
})

test_that("analyze_series' ACF/PACF order suggestions are directionally correct on known processes", {
  set.seed(42)
  n <- 300
  dates <- seq.Date(as.Date("2020-01-01"), by = "day", length.out = n)

  white_noise <- data.frame(ds = dates, y = stats::rnorm(n))
  a_wn <- analyze_series(white_noise, "day")
  expect_equal(a_wn$arima_p, 0L)
  expect_equal(a_wn$arima_q, 0L)

  ar2 <- data.frame(ds = dates, y = as.numeric(stats::arima.sim(list(ar = c(0.6, -0.3)), n = n)))
  a_ar2 <- analyze_series(ar2, "day")
  expect_equal(a_ar2$arima_p, 2L)

  ma1 <- data.frame(ds = dates, y = as.numeric(stats::arima.sim(list(ma = c(0.7)), n = n)))
  a_ma1 <- analyze_series(ma1, "day")
  expect_equal(a_ma1$arima_q, 1L)

  # p/q/P/Q are always well-formed non-negative integers, capped, never NA
  for (a in list(a_wn, a_ar2, a_ma1)) {
    for (field in c("arima_p", "arima_q", "arima_P", "arima_Q")) {
      expect_false(is.na(a[[field]]))
      expect_true(a[[field]] >= 0 && a[[field]] <= 3)
    }
  }
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
