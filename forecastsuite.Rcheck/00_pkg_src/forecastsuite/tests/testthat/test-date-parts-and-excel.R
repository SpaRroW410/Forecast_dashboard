test_that("compose_date_parts builds quarterly dates from Year + Quarter", {
  df <- data.frame(yr = rep(2022:2023, each = 4),
                    q = rep(c("Q1", "Q2", "Q3", "Q4"), 2))
  res <- compose_date_parts(df, year_col = "yr", quarter_col = "q")
  expect_equal(res$granularity, "quarter")
  expect_equal(format(res$ds[1:4]), c("2022-01-01", "2022-04-01", "2022-07-01", "2022-10-01"))
})

test_that("compose_date_parts accepts numeric and named months", {
  named <- compose_date_parts(data.frame(yr = 2023, mo = c("Jan", "March", "DEC")),
                               year_col = "yr", month_col = "mo")
  expect_equal(res_granularity <- named$granularity, "month")
  expect_equal(format(named$ds), c("2023-01-01", "2023-03-01", "2023-12-01"))

  numeric <- compose_date_parts(data.frame(yr = 2023, mo = c(1, 3, 12)),
                                 year_col = "yr", month_col = "mo")
  expect_equal(format(numeric$ds), c("2023-01-01", "2023-03-01", "2023-12-01"))
})

test_that("compose_date_parts handles day and year-only granularity", {
  daily <- compose_date_parts(data.frame(yr = 2024, mo = 2, dy = 29),
                               year_col = "yr", month_col = "mo", day_col = "dy")
  expect_equal(daily$granularity, "day")
  expect_equal(format(daily$ds), "2024-02-29")

  yearly <- compose_date_parts(data.frame(yr = 2020:2022), year_col = "yr")
  expect_equal(yearly$granularity, "year")
  expect_equal(format(yearly$ds), c("2020-01-01", "2021-01-01", "2022-01-01"))
})

test_that("compose_date_parts rejects contradictory or incomplete selections", {
  df <- data.frame(yr = 2023, q = 1, mo = 1, dy = 1)
  expect_error(compose_date_parts(df, "yr", quarter_col = "q", month_col = "mo"), "not both")
  expect_error(compose_date_parts(df, "yr", day_col = "dy"), "needs a Month")
  expect_error(compose_date_parts(df, ""), "Year column is required")
  expect_error(compose_date_parts(data.frame(yr = c("x", "y")), "yr"), "Could not build")
})

test_that("horizon and ts frequency support quarter and year", {
  expect_equal(convert_months_to_horizon(12, "quarter"), 4)
  expect_equal(convert_months_to_horizon(24, "year"), 2)
  expect_equal(ts_frequency_for("quarter"), 4)
  expect_equal(ts_frequency_for("year"), 1)
})

test_that("analyze_series works at quarterly granularity", {
  df <- data.frame(
    ds = seq(as.POSIXct("2015-01-01"), by = "quarter", length.out = 40),
    y  = 100 + 10 * sin(2 * pi * (1:40) / 4) + stats::rnorm(40, 0, 2)
  )
  a <- analyze_series(df, "quarter")
  expect_equal(a$detected_freq, 4)
  expect_gt(a$seasonal_strength, 0.5)
})

test_that("finalizing from Year + Quarter clamps aggregation to quarterly", {
  skip_if_not_installed("writexl")
  path <- tempfile(fileext = ".xlsx")
  writexl::write_xlsx(list(Quarterly = data.frame(
    Year = rep(2018:2023, each = 4),
    Quarter = rep(c("Q1", "Q2", "Q3", "Q4"), 6),
    Sales = round(stats::rnorm(24, 500, 40))
  )), path)

  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "file")
    session$setInputs(fs_file = list(datapath = path, name = "q.xlsx"))
    expect_equal(nrow(raw_data()), 24)

    session$setInputs(fs_date_mode = "parts")
    session$setInputs(fs_year_col = "Year", fs_quarter_col = "Quarter",
                       fs_month_col = "", fs_day_col = "")
    session$setInputs(fs_value_col = "Sales")
    session$setInputs(fs_date_agg = "day")   # deliberately finer than the data
    session$setInputs(fs_finalize_data = 1)

    expect_equal(nrow(final_dataset()), 24)
    # the clamp must be visible to downstream consumers, not just the widget
    expect_equal(effective_date_agg(), "quarter")
  })
})

test_that("Excel import reads the requested worksheet", {
  skip_if_not_installed("writexl")
  skip_if_not_installed("readxl")
  path <- tempfile(fileext = ".xlsx")
  writexl::write_xlsx(list(
    First  = data.frame(a = 1:3, b = 4:6),
    Second = data.frame(x = 1:5, y = 6:10)
  ), path)

  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "file")
    session$setInputs(fs_file = list(datapath = path, name = "book.xlsx"))
    expect_setequal(names(raw_data()), c("a", "b"))

    session$setInputs(fs_sheet = "Second")
    expect_setequal(names(raw_data()), c("x", "y"))
    expect_equal(nrow(raw_data()), 5)
  })
})
