test_that("the import UI exposes an Individual Observations data format option", {
  html <- as.character(build_app_ui())
  expect_true(grepl("fs_data_type", html, fixed = TRUE))
  expect_true(grepl("Individual Observations", html, fixed = TRUE))
  expect_true(grepl("Aggregated", html, fixed = TRUE))
})

test_that("individual-observation mode counts one event per row into periods", {
  set.seed(1)
  events <- data.frame(
    case_date = sample(seq.Date(as.Date("2023-01-01"), as.Date("2023-06-30"), by = "day"),
                        500, replace = TRUE)
  )
  path <- tempfile(fileext = ".csv")
  utils::write.csv(events, path, row.names = FALSE)

  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "file")
    session$setInputs(fs_file = list(datapath = path, name = "events.csv"))
    session$setInputs(fs_date_mode = "single", fs_date_col = "case_date")
    session$setInputs(fs_data_type = "individual")
    session$setInputs(fs_date_agg = "month")
    session$setInputs(fs_finalize_data = 1)

    fd <- final_dataset()
    expect_equal(nrow(fd), 6)          # 6 calendar months in the range
    expect_equal(sum(fd$y), 500)       # every row counted, none dropped
  })
})

test_that("a single-column table (just a date) is accepted for individual mode", {
  # A regression check: single-column import used to be rejected outright by
  # the >= 2 columns guard meant for aggregated (date + value) data.
  events <- data.frame(d = as.Date("2024-01-01") + 0:9)
  path <- tempfile(fileext = ".csv")
  utils::write.csv(events, path, row.names = FALSE)

  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "file")
    session$setInputs(fs_file = list(datapath = path, name = "single.csv"))
    expect_equal(ncol(raw_data()), 1)
    session$setInputs(fs_date_mode = "single", fs_date_col = "d")
    session$setInputs(fs_data_type = "individual")
    session$setInputs(fs_date_agg = "day")
    session$setInputs(fs_finalize_data = 1)

    fd <- final_dataset()
    expect_equal(nrow(fd), 10)
    expect_true(all(fd$y == 1))
  })
})

test_that("individual-observation mode does not require a Value column", {
  events <- data.frame(when = as.Date("2024-01-01") + 0:19)
  path <- tempfile(fileext = ".csv")
  utils::write.csv(events, path, row.names = FALSE)

  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "file")
    session$setInputs(fs_file = list(datapath = path, name = "e2.csv"))
    session$setInputs(fs_date_mode = "single", fs_date_col = "when")
    session$setInputs(fs_data_type = "individual")
    session$setInputs(fs_date_agg = "week")
    # fs_value_col is deliberately left unset -- individual mode shouldn't need it.
    session$setInputs(fs_finalize_data = 1)
    expect_false(is.null(final_dataset()))
    expect_equal(sum(final_dataset()$y), 20)
  })
})

test_that("population normalization composes correctly on top of individual-observation mode", {
  set.seed(2)
  events <- data.frame(
    case_date = sample(seq.Date(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "day"),
                        500, replace = TRUE)
  )
  pop <- data.frame(year = 2023, pop = 1e5)
  epath <- tempfile(fileext = ".csv"); utils::write.csv(events, epath, row.names = FALSE)
  ppath <- tempfile(fileext = ".csv"); utils::write.csv(pop, ppath, row.names = FALSE)

  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "file")
    session$setInputs(fs_file = list(datapath = epath, name = "e3.csv"))
    session$setInputs(fs_date_mode = "single", fs_date_col = "case_date")
    session$setInputs(fs_data_type = "individual")
    session$setInputs(fs_date_agg = "quarter")

    session$setInputs(fs_pop_file = list(datapath = ppath, name = "p.csv"))
    session$setInputs(fs_use_population = TRUE,
                       fs_pop_date_col = "year", fs_pop_value_col = "pop",
                       fs_pop_freq = "year", fs_pop_multiplier = 1, fs_unit_scale = 1e5)
    session$setInputs(fs_finalize_data = 1)

    fd <- final_dataset()
    expect_equal(nrow(fd), 4)
    expect_true(all(fd$y > 0))
    # 500 events / 1e5 population * 1e5 unit scale == the raw quarterly counts
    expect_equal(sum(fd$y), 500)
  })
})

test_that("switching back to Aggregated mode still requires a Value column", {
  events <- data.frame(when = as.Date("2024-01-01") + 0:9, val = 1:10)
  path <- tempfile(fileext = ".csv")
  utils::write.csv(events, path, row.names = FALSE)

  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "file")
    session$setInputs(fs_file = list(datapath = path, name = "agg.csv"))
    session$setInputs(fs_date_mode = "single", fs_date_col = "when")
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_agg = "day")
    # fs_value_col left unset -- Finalize should simply not fire (req() blocks it).
    session$setInputs(fs_finalize_data = 1)
    expect_null(final_dataset())

    session$setInputs(fs_value_col = "val")
    session$setInputs(fs_finalize_data = 2)
    expect_equal(nrow(final_dataset()), 10)
  })
})
