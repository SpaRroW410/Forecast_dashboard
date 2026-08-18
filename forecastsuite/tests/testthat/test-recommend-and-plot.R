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

test_that("plot_forecast_generic honors custom colors for actual/forecast/trend/CI", {
  tib <- tibble::tibble(ds = Sys.Date() + 1:10, yhat = rnorm(10),
                          yhat_lower = rnorm(10) - 1, yhat_upper = rnorm(10) + 1,
                          trend = rnorm(10))
  train <- tibble::tibble(ds = Sys.Date() - 10:1, y = rnorm(10))
  p <- plot_forecast_generic(tib, train_df = train,
                              color_actual = "#111111", color_forecast = "#222222",
                              color_trend = "#333333", color_ci = "#444444")
  lines <- p$x$attrs[vapply(p$x$attrs, function(a) identical(a$name, "Actual"), logical(1))]
  expect_equal(lines[[1]]$line$color, "#111111")
  fc_lines <- p$x$attrs[vapply(p$x$attrs, function(a) identical(a$name, "Forecast"), logical(1))]
  expect_equal(fc_lines[[1]]$line$color, "#222222")
  trend_lines <- p$x$attrs[vapply(p$x$attrs, function(a) identical(a$name, "Trend"), logical(1))]
  expect_equal(trend_lines[[1]]$line$color, "#333333")
})

test_that("plot appearance toggles actually suppress the corresponding trace", {
  tib <- tibble::tibble(ds = Sys.Date() + 1:10, yhat = rnorm(10),
                          yhat_lower = rnorm(10) - 1, yhat_upper = rnorm(10) + 1,
                          trend = rnorm(10))
  p_on <- plot_forecast_generic(tib, show_trend = TRUE, show_uncertainty = TRUE)
  p_off <- plot_forecast_generic(tib, show_trend = FALSE, show_uncertainty = FALSE)
  names_on <- vapply(p_on$x$attrs, function(a) if (is.null(a$name)) "" else a$name, "")
  names_off <- vapply(p_off$x$attrs, function(a) if (is.null(a$name)) "" else a$name, "")
  expect_true("Trend" %in% names_on)
  expect_true("Uncertainty" %in% names_on)
  expect_false("Trend" %in% names_off)
  expect_false("Uncertainty" %in% names_off)
})

test_that("render_forecast_png writes a valid, non-trivial PNG file", {
  tib <- tibble::tibble(ds = Sys.Date() + 1:10, yhat = rnorm(10) + 100,
                          yhat_lower = rnorm(10) + 95, yhat_upper = rnorm(10) + 105,
                          trend = rnorm(10) + 100)
  train <- tibble::tibble(ds = Sys.Date() - 10:1, y = rnorm(10) + 100)
  path <- tempfile(fileext = ".png")
  render_forecast_png(path, tib, train_df = train, show_trend = TRUE, show_uncertainty = TRUE)
  expect_true(file.exists(path))
  expect_gt(file.info(path)$size, 1000)
  header <- readBin(path, "raw", 8)
  expect_equal(header, as.raw(c(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)))
})

test_that("render_comparison_png writes a valid PNG for multiple models", {
  fcs <- list(
    ARIMA = tibble::tibble(ds = Sys.Date() + 1:10, yhat = rnorm(10) + 100),
    ETS   = tibble::tibble(ds = Sys.Date() + 1:10, yhat = rnorm(10) + 105)
  )
  train <- tibble::tibble(ds = Sys.Date() - 10:1, y = rnorm(10) + 100)
  path <- tempfile(fileext = ".png")
  render_comparison_png(path, fcs, train_df = train)
  expect_true(file.exists(path))
  expect_gt(file.info(path)$size, 1000)
})

test_that("render_comparison_png errors clearly when there is nothing to plot", {
  path <- tempfile(fileext = ".png")
  expect_error(render_comparison_png(path, list(a = NULL, b = NULL)), "No forecasts")
})
