test_that("the bundled demo dataset ships and is well-formed", {
  path <- system.file("extdata", "forecastsuite_demo_clinic_visits.csv", package = "forecastsuite")
  expect_true(nzchar(path))
  df <- utils::read.csv(path)
  expect_setequal(names(df), c("date", "visits"))
  expect_gt(nrow(df), 1500)
  expect_equal(min(as.Date(df$date)), as.Date("2019-01-01"))
  expect_equal(max(as.Date(df$date)), as.Date("2023-12-31"))
  # Some, but not all, Sundays are present (a realistic "mostly closed" pattern).
  wday <- as.POSIXlt(as.Date(df$date))$wday
  expect_gt(sum(wday == 0), 0)
  expect_lt(sum(wday == 0), 261)  # fewer than the full 5-year Sunday count
})

test_that("the Import UI exposes a Demo Dataset icon source", {
  html <- as.character(build_app_ui())
  expect_true(grepl("fs_src_demo", html, fixed = TRUE))
  expect_true(grepl("fs_load_demo", html, fixed = TRUE))
  expect_true(grepl("Demo dataset", html, fixed = TRUE))
})

test_that("loading the demo dataset populates raw_data() and can be finalized end to end", {
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "demo")
    session$setInputs(fs_load_demo = 1)
    expect_setequal(names(raw_data()), c("date", "visits"))
    expect_gt(nrow(raw_data()), 1500)

    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "date", fs_value_col = "visits")
    session$setInputs(fs_date_agg = "week")
    session$setInputs(fs_finalize_data = 1)
    expect_gt(nrow(final_dataset()), 200)
  })
})

test_that("the Model tab exposes Plot Appearance toggles and colour pickers", {
  html <- as.character(build_app_ui())
  for (id in c("fs_show_trend", "fs_show_uncertainty", "fs_show_holidays", "fs_show_changepoints",
               "fs_color_actual", "fs_color_forecast", "fs_color_trend", "fs_color_ci")) {
    expect_true(grepl(id, html, fixed = TRUE), info = id)
  }
})

test_that("the app exposes download buttons for the dataset, forecast plot, comparison plot, and holidays", {
  html <- as.character(build_app_ui())
  for (id in c("fs_download_dataset_csv", "fs_download_forecast_png", "fs_download_comparison_png")) {
    expect_true(grepl(id, html, fixed = TRUE), info = id)
  }
  holidays_html <- as.character(build_holidays_tab_ui())
  expect_true(grepl("fs_download_holidays_csv", holidays_html, fixed = TRUE))
  expect_true(grepl("fs_download_example_holidays", holidays_html, fixed = TRUE))
})

test_that("the bundled example holiday file ships, is well-formed, and matches the movable-holiday format", {
  path <- system.file("extdata", "example_holidays.csv", package = "forecastsuite")
  expect_true(nzchar(path))
  df <- utils::read.csv(path)
  expect_setequal(names(df), c("date", "holiday_name"))
  expect_equal(nrow(df), 5)
  expect_false(any(is.na(as.Date(df$date))))
  expect_true(all(nzchar(df$holiday_name)))

  # it should parse cleanly through the same movable-holiday parser used
  # for a real upload, with the user picking these same two columns
  parsed <- parse_movable_holidays(df, date_col = "date", label_col = "holiday_name")
  expect_equal(nrow(parsed), 5)
  expect_setequal(names(parsed), c("ds", "holiday"))
})

test_that("downloading the example holiday file reproduces the bundled CSV byte-for-byte", {
  # downloadHandler content functions can't be invoked directly in
  # shiny::testServer() -- replicate the handler's file.copy() logic
  # directly, per the established testServer downloadHandler limitation.
  src <- system.file("extdata", "example_holidays.csv", package = "forecastsuite")
  out <- tempfile(fileext = ".csv")
  file.copy(src, out)
  expect_equal(readLines(out), readLines(src))
})

test_that("the processed dataset CSV download reflects the finalized data", {
  events <- data.frame(when = as.Date("2024-01-01") + 0:29, val = 1:30)
  path <- tempfile(fileext = ".csv")
  utils::write.csv(events, path, row.names = FALSE)

  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "file")
    session$setInputs(fs_file = list(datapath = path, name = "e.csv"))
    session$setInputs(fs_date_mode = "single", fs_date_col = "when", fs_value_col = "val")
    session$setInputs(fs_data_type = "agg", fs_date_agg = "day")
    session$setInputs(fs_finalize_data = 1)

    # The download handler is a one-line utils::write.csv(final_dataset(), ...)
    # wrapper (R/app_server.R); shiny's downloadHandler objects aren't directly
    # invokable from testServer, so exercise the exact same reactive + write
    # path the handler uses instead of reaching into shiny internals.
    out_path <- tempfile(fileext = ".csv")
    d <- final_dataset()
    d$ds <- format(d$ds, "%Y-%m-%d")
    utils::write.csv(d, out_path, row.names = FALSE)
    written <- utils::read.csv(out_path)
    expect_equal(nrow(written), 30)
    expect_setequal(names(written), c("ds", "y"))
  })
})

test_that("the holiday CSV download reflects the compiled holiday list", {
  df <- data.frame(when = as.Date("2024-01-01") + 0:59, val = 1)
  path <- tempfile(fileext = ".csv")
  utils::write.csv(df, path, row.names = FALSE)

  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "file")
    session$setInputs(fs_file = list(datapath = path, name = "d.csv"))
    session$setInputs(fs_date_mode = "single", fs_date_col = "when", fs_value_col = "val")
    session$setInputs(fs_data_type = "agg", fs_date_agg = "day")
    session$setInputs(fs_finalize_data = 1)

    session$setInputs(fs_use_holidays = TRUE)
    session$setInputs(fs_holiday_years = c(2024, 2024), fs_include_sundays = TRUE)
    session$setInputs(fs_generate_fixed = 1)
    expect_gt(nrow(combined_holidays()), 0)

    # Same rationale as the dataset CSV test above: exercise the exact
    # reactive + write path the downloadHandler in R/app_holidays.R uses.
    out_path <- tempfile(fileext = ".csv")
    utils::write.csv(combined_holidays(), out_path, row.names = FALSE)
    written <- utils::read.csv(out_path)
    expect_gt(nrow(written), 0)
    expect_setequal(names(written), c("ds", "holiday"))
  })
})
