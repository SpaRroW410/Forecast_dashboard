test_that("analyze_series detects trend and seasonality on a synthetic series", {
  df <- make_synthetic_series(n = 400)
  a <- analyze_series(df, "day")
  expect_gt(a$trend_strength, 0.5)
  expect_gt(a$seasonal_strength, 0.8)
  expect_equal(a$detected_freq, 7)
})

test_that("recommend_model ranks candidates and explains why", {
  df <- make_synthetic_series(n = 400)
  a <- analyze_series(df, "day")
  ranked <- recommend_model(a, holidays_configured = FALSE, candidates = c("prophet", "arima"))
  expect_equal(nrow(ranked), 2)
  expect_true(all(nchar(ranked$reason) > 0))
  expect_true(all(diff(ranked$score) <= 0))
})

test_that("recommend_model defaults to every currently-available model", {
  df <- make_synthetic_series(n = 400)
  a <- analyze_series(df, "day")
  ranked <- recommend_model(a, holidays_configured = TRUE)
  available_keys <- vapply(list_models(available_only = TRUE), function(m) m$key, "")
  expect_setequal(ranked$key, available_keys)
})

test_that("plot_forecast_generic works on a plain ds/yhat tibble", {
  tib <- tibble::tibble(ds = Sys.Date() + 1:10, yhat = rnorm(10))
  p <- plot_forecast_generic(tib)
  expect_s3_class(p, "plotly")
})

test_that("plot_forecast_generic works on Prophet's richer forecast frame", {
  df <- make_synthetic_series(n = 200)
  m <- get_model("prophet")
  fit_obj <- m$fit(df, date_agg = "day", exclude_sundays = FALSE, yearly = FALSE, weekly = TRUE, daily = FALSE)
  fc_obj <- m$forecast(fit_obj, 10)
  p <- plot_forecast_generic(fc_obj, train_df = df, model_obj = fit_obj,
                              show_trend = TRUE, show_changepoints = TRUE)
  expect_s3_class(p, "plotly")
})
