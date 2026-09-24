test_that("collapse_to_period sums rows sharing a period", {
  df <- tibble::tibble(
    ds = as.POSIXct(rep(c("2021-01-15", "2021-02-20", "2021-04-05"), each = 3)),
    y  = c(1, 2, 3,  10, 20, 30,  100, 200, 300)
  )
  q <- collapse_to_period(df, "quarter", fun = "sum")
  expect_equal(nrow(q), 2)
  expect_equal(q$y, c(66, 600))
  expect_equal(sum(q$y), sum(df$y))
})

test_that("collapse_to_period supports mean/median and an opt-out", {
  df <- tibble::tibble(ds = as.POSIXct(rep("2021-01-15", 3)), y = c(1, 2, 6))
  expect_equal(collapse_to_period(df, "month", "mean")$y, 3)
  expect_equal(collapse_to_period(df, "month", "median")$y, 2)
  expect_equal(nrow(collapse_to_period(df, "month", "none")), 3)
})

test_that("collapse_to_period snaps to the right period boundary", {
  df <- tibble::tibble(ds = as.POSIXct(c("2021-08-15", "2021-08-31")), y = c(1, 1))
  expect_equal(format(collapse_to_period(df, "month")$ds, "%Y-%m-%d"), "2021-08-01")
  expect_equal(format(collapse_to_period(df, "year")$ds, "%Y-%m-%d"), "2021-01-01")
})

test_that("count_duplicate_periods reports how many rows would merge", {
  df <- tibble::tibble(ds = as.POSIXct(rep(c("2021-01-01", "2021-04-01"), each = 4)), y = 1)
  expect_equal(count_duplicate_periods(df, "quarter"), 6L)
  expect_equal(count_duplicate_periods(df, "day"), 6L)
})

test_that("collapse_to_period validates its input", {
  expect_error(collapse_to_period(tibble::tibble(a = 1), "day"), "ds and y")
})

test_that("finalizing many rows per quarter collapses to one row per quarter", {
  set.seed(5)
  tb <- do.call(rbind, lapply(2021:2023, function(y) do.call(rbind, lapply(1:4, function(q)
    data.frame(Year = y, Quarter = q, District = paste0("D", 1:6),
               Cases = sample(20:90, 6))))))
  path <- tempfile(fileext = ".csv")
  utils::write.csv(tb, path, row.names = FALSE)

  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "file")
    session$setInputs(fs_file = list(datapath = path, name = "tb.csv"))
    session$setInputs(fs_date_mode = "parts")
    session$setInputs(fs_year_col = "Year", fs_quarter_col = "Quarter",
                       fs_month_col = "", fs_day_col = "")
    session$setInputs(fs_value_col = "Cases", fs_date_agg = "quarter",
                       fs_collapse_fun = "sum")
    session$setInputs(fs_finalize_data = 1)

    fd <- final_dataset()
    expect_equal(nrow(fd), 12)              # 3 years x 4 quarters
    expect_equal(sum(fd$y), sum(tb$Cases))  # nothing lost
    expect_equal(length(unique(fd$ds)), 12) # no repeated periods
  })
})

test_that("selecting the same column for date and value is refused", {
  path <- tempfile(fileext = ".csv")
  utils::write.csv(data.frame(Year = 2021:2024, Cases = 1:4), path, row.names = FALSE)

  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "file")
    session$setInputs(fs_file = list(datapath = path, name = "x.csv"))
    session$setInputs(fs_date_mode = "single", fs_date_col = "Year",
                       fs_value_col = "Year", fs_date_agg = "year")
    session$setInputs(fs_finalize_data = 1)
    expect_null(final_dataset())
  })
})
