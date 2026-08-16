df <- make_synthetic_series()
train_df <- df[1:250, ]
test_df  <- df[251:300, ]
h <- nrow(test_df)

test_that("arima adapter fits, forecasts, and produces a ds/yhat tibble", {
  m <- get_model("arima")
  fit_obj <- m$fit(train_df, date_agg = "day")
  fc_obj <- m$forecast(fit_obj, h)
  tib <- m$to_tibble(fc_obj, test_df)
  expect_true(all(c("ds", "yhat") %in% names(tib)))
  expect_equal(nrow(tib), h)
  expect_match(m$annotate(fit_obj), "^ARIMA\\(")
})

test_that("arima adapter supports manual order entry", {
  m <- get_model("arima")
  fit_obj <- m$fit(train_df, date_agg = "day", auto = FALSE, order = c(2, 1, 1))
  expect_equal(m$annotate(fit_obj), "ARIMA(2,1,1)")
})

test_that("sarima adapter fits with a seasonal manual order", {
  weekly_df <- tibble::tibble(
    ds = seq.Date(as.Date("2015-01-01"), by = "week", length.out = 150),
    y = 50 + 10 * sin(2 * pi * (1:150) / 52) + stats::rnorm(150, 0, 2)
  )
  m <- get_model("sarima")
  fit_obj <- m$fit(weekly_df, date_agg = "week", auto = FALSE, order = c(1, 1, 1), seasonal_order = c(1, 0, 0))
  expect_match(m$annotate(fit_obj), "^ARIMA\\(1,1,1\\)\\(1,0,0\\)\\[52\\]$")
})

test_that("ets/tbats/nnetar/holtwinters adapters all fit and forecast without error", {
  for (key in c("ets", "tbats", "nnetar", "holtwinters")) {
    m <- get_model(key)
    fit_obj <- m$fit(train_df, date_agg = "day")
    fc_obj <- m$forecast(fit_obj, h)
    tib <- m$to_tibble(fc_obj, test_df)
    expect_true(all(c("ds", "yhat") %in% names(tib)), info = key)
    expect_equal(nrow(tib), h, info = key)
  }
})

test_that("holtwinters falls back gracefully on a short series (< 2 seasonal cycles)", {
  short_df <- df[1:60, ]
  m <- get_model("holtwinters")
  fit_obj <- expect_no_error(m$fit(short_df, date_agg = "day"))
  expect_false(fit_obj$gamma)
})

test_that("prophet adapter fits, forecasts, and keeps yhat/interval columns", {
  m <- get_model("prophet")
  fit_obj <- m$fit(train_df, date_agg = "day", exclude_sundays = FALSE,
                    yearly = FALSE, weekly = TRUE, daily = FALSE)
  fc_obj <- m$forecast(fit_obj, h)
  expect_true(is.data.frame(fc_obj))
  expect_true("trend" %in% names(fc_obj))
  tib <- m$to_tibble(fc_obj, test_df)
  expect_true(all(c("ds", "yhat", "yhat_lower", "yhat_upper") %in% names(tib)))
})
