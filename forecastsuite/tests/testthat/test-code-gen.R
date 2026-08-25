test_that("build_fit_code produces parseable, runnable code for a non-prophet model", {
  code <- build_fit_code("arima", "day", scalar_args = list(auto = FALSE, order = c(2, 1, 1)),
                          uses_holidays = FALSE, horizon = 30)
  expect_no_error(parse(text = code))
  expect_match(code, "library\\(forecastsuite\\)")
  expect_match(code, 'get_model\\("arima"\\)')
  expect_match(code, "order = c\\(2, 1, 1\\)")
  expect_false(grepl("holidays_df", code))

  df <- make_synthetic_series(n = 200)
  train_df <- df[1:150, ]
  test_df <- df[151:200, ]
  env <- list2env(list(train_df = train_df, test_df = test_df))
  result <- eval(parse(text = code), envir = env)
  expect_s3_class(result, "plotly")
})

test_that("build_fit_code references holidays_df as a variable, never inlines it", {
  code <- build_fit_code("prophet", "day",
                          scalar_args = list(cp = 0.05, season = 10, holiday = 5,
                                              exclude_sundays = FALSE, yearly = TRUE, weekly = TRUE, daily = FALSE),
                          uses_holidays = TRUE, horizon = 30)
  expect_no_error(parse(text = code))
  expect_match(code, "holidays_df = holidays_df")

  df <- make_synthetic_series(n = 200)
  train_df <- df[1:150, ]
  test_df <- df[151:200, ]
  holidays_df <- NULL
  env <- list2env(list(train_df = train_df, test_df = test_df, holidays_df = holidays_df))
  result <- eval(parse(text = code), envir = env)
  expect_s3_class(result, "plotly")
})

test_that("build_comparison_code produces parseable, runnable code across several models", {
  code <- build_comparison_code(c("arima", "ets"), "day", 30)
  expect_no_error(parse(text = code))
  expect_match(code, 'c\\("arima", "ets"\\)')

  df <- make_synthetic_series(n = 200)
  train_df <- df[1:150, ]
  test_df <- df[151:200, ]
  env <- list2env(list(train_df = train_df, test_df = test_df))
  result <- eval(parse(text = code), envir = env)
  expect_s3_class(result, "data.frame")
  expect_setequal(unique(result$Set), c(get_model("arima")$label, get_model("ets")$label))
})

test_that("highlight_r_code wraps keywords, strings, comments, and numbers, and HTML-escapes the rest", {
  code <- 'library(forecastsuite)\nmodel <- get_model("arima") # fit\nx <- 1.5'
  html <- highlight_r_code(code)

  expect_true(startsWith(html, '<pre class="fs-code">'))
  expect_true(endsWith(html, "</pre>"))
  expect_true(grepl('<span class="hl-kw">library</span>', html, fixed = TRUE))
  expect_true(grepl('<span class="hl-str">&quot;arima&quot;</span>', html, fixed = TRUE) ||
                grepl('<span class="hl-str">"arima"</span>', html, fixed = TRUE))
  expect_true(grepl('<span class="hl-comment"># fit</span>', html, fixed = TRUE))
  expect_true(grepl('<span class="hl-num">1.5</span>', html, fixed = TRUE))
})

test_that("highlight_r_code HTML-escapes angle brackets and ampersands outside of tokens", {
  code <- "x <- a & b"
  html <- highlight_r_code(code)
  expect_true(grepl("&amp;", html, fixed = TRUE))
  expect_false(grepl("x <- a & b", html, fixed = TRUE))
})

test_that("highlight_r_code handles NULL/empty input without erroring", {
  expect_equal(highlight_r_code(NULL), "")
  expect_equal(highlight_r_code(""), "")
})

test_that("the Model tab UI exposes the copy-to-clipboard button and the highlighted-code output", {
  html <- as.character(build_model_tab_ui())
  expect_true(grepl("fs_copy_code", html, fixed = TRUE))
  expect_true(grepl("fs_generated_code_html", html, fixed = TRUE))
})
