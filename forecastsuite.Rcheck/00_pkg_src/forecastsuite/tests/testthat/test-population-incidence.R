test_that("population normalization converts counts to incidence", {
  # 4 quarters of 2021, two districts each -> 8 rows; population 1,000,000
  counts <- data.frame(
    Year    = 2021,
    Quarter = rep(1:4, each = 2),
    Cases   = c(50, 50, 60, 40, 70, 30, 80, 20)   # 100 per quarter
  )
  pop <- data.frame(Year = 2021, Population = 1e6)

  cpath <- tempfile(fileext = ".csv"); utils::write.csv(counts, cpath, row.names = FALSE)
  ppath <- tempfile(fileext = ".csv"); utils::write.csv(pop, ppath, row.names = FALSE)

  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "file")
    session$setInputs(fs_file = list(datapath = cpath, name = "c.csv"))
    session$setInputs(fs_date_mode = "parts")
    session$setInputs(fs_year_col = "Year", fs_quarter_col = "Quarter",
                       fs_month_col = "", fs_day_col = "")
    session$setInputs(fs_value_col = "Cases", fs_date_agg = "quarter",
                       fs_collapse_fun = "sum")

    session$setInputs(fs_pop_file = list(datapath = ppath, name = "p.csv"))
    session$setInputs(fs_use_population = TRUE,
                       fs_pop_date_col = "Year", fs_pop_value_col = "Population",
                       fs_pop_freq = "year",
                       fs_pop_multiplier = 1, fs_unit_scale = 1e5)
    session$setInputs(fs_finalize_data = 1)

    fd <- final_dataset()
    expect_equal(nrow(fd), 4)          # collapsed to one row per quarter
    # counts are summed BEFORE dividing, so each quarter is 100 cases
    expect_true(all(fd$y > 0))
    expect_equal(length(unique(round(fd$y, 6))), 1)  # equal counts -> equal incidence
  })
})

test_that("enabling population without a table is refused", {
  path <- tempfile(fileext = ".csv")
  utils::write.csv(data.frame(date = Sys.Date() + 1:10, v = 1:10), path, row.names = FALSE)
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "file")
    session$setInputs(fs_file = list(datapath = path, name = "d.csv"))
    session$setInputs(fs_date_mode = "single", fs_date_col = "date",
                       fs_value_col = "v", fs_date_agg = "day")
    session$setInputs(fs_use_population = TRUE)
    session$setInputs(fs_finalize_data = 1)
    expect_null(final_dataset())
  })
})
