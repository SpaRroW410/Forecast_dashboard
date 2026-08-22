test_that("process_uploaded_data retains the grouping column instead of dropping it", {
  df <- data.frame(
    Date = as.Date("2021-01-01") + 0:9,
    Cases = 1:10,
    District = rep(c("A", "B"), 5)
  )
  out <- process_uploaded_data(df, type = "agg", date_col = "Date", value_col = "Cases",
                                group_col = "District")
  expect_setequal(names(out), c("ds", "y", "District"))
  expect_setequal(unique(out$District), c("A", "B"))
  expect_equal(nrow(out), 10)

  # Without group_col, the ungrouped behavior is unchanged: the column is
  # silently dropped, exactly as before this feature existed.
  out_ungrouped <- process_uploaded_data(df, type = "agg", date_col = "Date", value_col = "Cases")
  expect_setequal(names(out_ungrouped), c("ds", "y"))
})

test_that("process_uploaded_data(type = 'individual') keeps the group column through summarise()", {
  set.seed(1)
  df <- data.frame(
    when = sample(seq.Date(as.Date("2022-01-01"), as.Date("2022-01-31"), by = "day"), 40, replace = TRUE),
    Sex = sample(c("Male", "Female"), 40, replace = TRUE)
  )
  out <- process_uploaded_data(df, type = "individual", date_col = "when", date_agg = "week",
                                group_col = "Sex")
  expect_setequal(names(out), c("ds", "y", "Sex"))
  expect_equal(sum(out$y), 40)
  expect_setequal(unique(out$Sex), c("Male", "Female"))
})

test_that("process_uploaded_data population join is group-aware when the population table has a group key", {
  pop <- data.frame(Year = 2021, District = c("A", "B"), Population = c(1e6, 5e5))

  grouped <- data.frame(ds = as.Date(c("2021-01-01", "2021-04-01", "2021-01-01", "2021-04-01")),
                          y = c(100, 120, 50, 60),
                          District = c("A", "A", "B", "B"))
  out <- process_uploaded_data(grouped, type = "agg", date_col = "ds", value_col = "y",
                                group_col = "District",
                                pop_df = pop, pop_date_col = "Year", pop_value_col = "Population",
                                pop_group_col = "District", pop_freq = "year", unit_divisor = 1e5,
                                date_agg = "quarter")
  a_y <- out$y[out$District == "A" & out$ds == as.Date("2021-01-01")]
  b_y <- out$y[out$District == "B" & out$ds == as.Date("2021-01-01")]
  expect_equal(a_y, 100 / 1e6 * 1e5)
  expect_equal(b_y, 50 / 5e5 * 1e5)

  # The aggregate call (group_col = NULL) sums population across groups
  # rather than requiring a separately-supplied total.
  aggregate_collapsed <- data.frame(ds = as.Date(c("2021-01-01", "2021-04-01")), y = c(150, 180))
  agg_out <- process_uploaded_data(aggregate_collapsed, type = "agg", date_col = "ds", value_col = "y",
                                    group_col = NULL,
                                    pop_df = pop, pop_date_col = "Year", pop_value_col = "Population",
                                    pop_group_col = "District", pop_freq = "year", unit_divisor = 1e5,
                                    date_agg = "quarter")
  expect_equal(agg_out$y[agg_out$ds == as.Date("2021-01-01")], 150 / 1.5e6 * 1e5)
})

test_that("a population table with no group column only ever normalizes the aggregate view", {
  pop <- data.frame(Year = 2021, Population = 1e6)  # no district breakdown

  grouped <- data.frame(ds = as.Date(c("2021-01-01", "2021-01-01")), y = c(100, 50),
                          District = c("A", "B"))
  # pop_group_col supplied but absent from pop_df -> has_pop_group is FALSE,
  # falls back to the plain date-only join (same figure applied to every row).
  out <- process_uploaded_data(grouped, type = "agg", date_col = "ds", value_col = "y",
                                group_col = "District",
                                pop_df = pop, pop_date_col = "Year", pop_value_col = "Population",
                                pop_group_col = "District", pop_freq = "year", unit_divisor = 1e5,
                                date_agg = "quarter")
  expect_equal(out$y[out$District == "A"], 100 / 1e6 * 1e5)
  expect_equal(out$y[out$District == "B"], 50 / 1e6 * 1e5)
})

test_that("collapse_to_period collapses within each group instead of across all of them", {
  df <- data.frame(
    ds = rep(as.Date(c("2021-01-01", "2021-01-01", "2021-04-01", "2021-04-01")), 1),
    y  = c(50, 50, 60, 40),
    District = c("A", "B", "A", "B")
  )
  out <- collapse_to_period(df, "quarter", "sum", group_col = "District")
  expect_equal(nrow(out), 4)
  expect_equal(out$y[out$District == "A" & out$ds == as.Date("2021-01-01")], 50)
  expect_equal(out$y[out$District == "B" & out$ds == as.Date("2021-01-01")], 50)

  # Without group_col, behavior is unchanged: districts sum together.
  out_ungrouped <- collapse_to_period(df, "quarter", "sum")
  expect_equal(nrow(out_ungrouped), 2)
  expect_equal(out_ungrouped$y[out_ungrouped$ds == as.Date("2021-01-01")], 100)
})

test_that("count_duplicate_periods only counts rows sharing BOTH a period and a group", {
  df <- data.frame(
    ds = as.Date(c("2021-01-01", "2021-01-01", "2021-01-01")),
    y = c(1, 2, 3),
    District = c("A", "B", "A")
  )
  # (period, District) pairs: (Q1,A) x2, (Q1,B) x1 -> exactly one duplicate.
  expect_equal(count_duplicate_periods(df, "quarter", group_col = "District"), 1L)
  # Without group_col, all 3 collide on period alone -> 2 duplicates.
  expect_equal(count_duplicate_periods(df, "quarter"), 2L)
})

test_that("split_by_group returns a named list of per-group ds/y tibbles", {
  df <- data.frame(ds = as.Date("2021-01-01") + 0:5, y = 1:6,
                     District = c("B", "A", "B", "A", "B", "A"))
  out <- split_by_group(df, "District")
  expect_setequal(names(out), c("A", "B"))
  expect_equal(nrow(out$A), 3)
  expect_equal(nrow(out$B), 3)
  expect_setequal(names(out$A), c("ds", "y"))

  expect_null(split_by_group(df, NULL))
  expect_null(split_by_group(df, "NotAColumn"))
})
