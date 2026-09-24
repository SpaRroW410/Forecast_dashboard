test_that("the fixed-holiday catalog matches the hosted app", {
  cat_ <- fixed_holiday_catalog()
  expect_setequal(unname(cat_),
                  c("Republic Day", "Independence Day", "Gandhi Jayanti",
                    "Christmas", "Ambedkar Jayanti", "Makar Sankranti"))
  expect_equal(cat_[["01-26"]], "Republic Day")
  expect_equal(cat_[["12-25"]], "Christmas")
})

test_that("Sundays plus fixed holidays compile over the chosen year range", {
  shiny::testServer(build_app_server, {
    session$setInputs(fs_use_holidays = TRUE, fs_holiday_years = c(2021, 2022))
    session$setInputs(fs_include_sundays = FALSE,
                       fs_fixed_holidays = c("01-26", "12-25"))
    session$setInputs(fs_generate_fixed = 1)

    h <- combined_holidays()
    expect_equal(nrow(h), 4)                       # 2 holidays x 2 years
    expect_setequal(unique(h$holiday), c("Republic Day", "Christmas"))

    session$setInputs(fs_include_sundays = TRUE, fs_fixed_holidays = character(0))
    session$setInputs(fs_generate_fixed = 2)
    expect_true("Sunday" %in% combined_holidays()$holiday)
    expect_gt(sum(combined_holidays()$holiday == "Sunday"), 100)
  })
})

test_that("movable holidays are read from a file and title-cased", {
  path <- tempfile(fileext = ".csv")
  utils::write.csv(data.frame(Date = c("2021-11-04", "2022-10-24"),
                               Festival = c("diwali", "diwali")),
                    path, row.names = FALSE)

  shiny::testServer(build_app_server, {
    session$setInputs(fs_use_holidays = TRUE, fs_holiday_years = c(2021, 2022))
    session$setInputs(fs_movable_file = list(datapath = path, name = "m.csv"))
    session$setInputs(fs_movable_date_col = "Date", fs_movable_label_col = "Festival")
    session$setInputs(fs_add_movable = 1)

    h <- combined_holidays()
    expect_equal(nrow(h), 2)
    expect_equal(unique(h$holiday), "Diwali")
  })
})

test_that("a manual holiday can repeat across the year range or stand alone", {
  shiny::testServer(build_app_server, {
    session$setInputs(fs_use_holidays = TRUE, fs_holiday_years = c(2020, 2023))
    session$setInputs(fs_manual_type = "fixed",
                       fs_manual_date = as.Date("2021-05-01"),
                       fs_manual_label = "labour day")
    session$setInputs(fs_add_manual = 1)
    expect_equal(nrow(combined_holidays()), 4)     # one per year 2020-2023
    expect_equal(unique(combined_holidays()$holiday), "Labour Day")

    session$setInputs(fs_manual_type = "movable",
                       fs_manual_date = as.Date("2022-07-04"),
                       fs_manual_label = "one off")
    session$setInputs(fs_add_manual = 2)
    expect_equal(sum(combined_holidays()$holiday == "One Off"), 1)
  })
})

test_that("rows can be relabelled and removed, and the list cleared", {
  shiny::testServer(build_app_server, {
    session$setInputs(fs_use_holidays = TRUE, fs_holiday_years = c(2021, 2022))
    session$setInputs(fs_include_sundays = FALSE, fs_fixed_holidays = c("01-26", "12-25"))
    session$setInputs(fs_generate_fixed = 1)
    expect_equal(nrow(combined_holidays()), 4)

    session$setInputs(fs_holiday_table_rows_selected = c(1, 2), fs_new_label = "national day")
    session$setInputs(fs_apply_edit = 1)
    expect_equal(sum(combined_holidays()$holiday == "National Day"), 2)

    session$setInputs(fs_holiday_table_rows_selected = 1)
    session$setInputs(fs_remove_selected = 1)
    expect_equal(nrow(combined_holidays()), 3)

    session$setInputs(fs_clear_holidays = 1)
    expect_equal(nrow(combined_holidays()), 0)
  })
})

test_that("per-holiday windows reach the finalized list", {
  shiny::testServer(build_app_server, {
    session$setInputs(fs_use_holidays = TRUE, fs_holiday_years = c(2021, 2022))
    session$setInputs(fs_include_sundays = FALSE, fs_fixed_holidays = "12-25")
    session$setInputs(fs_generate_fixed = 1)

    session$setInputs(fs_window_label = "Christmas",
                       fs_lower_window = 2, fs_upper_window = 3)
    session$setInputs(fs_apply_window = 1)
    session$setInputs(fs_finalize_holidays = 1)

    fh <- final_holidays()
    expect_true(all(c("ds", "holiday", "lower_window", "upper_window") %in% names(fh)))
    expect_equal(unique(fh$lower_window), 2L)
    expect_equal(unique(fh$upper_window), 3L)
  })
})

test_that("disabling holiday effects finalizes to NULL", {
  shiny::testServer(build_app_server, {
    session$setInputs(fs_use_holidays = TRUE, fs_holiday_years = c(2021, 2021))
    session$setInputs(fs_include_sundays = FALSE, fs_fixed_holidays = "12-25")
    session$setInputs(fs_generate_fixed = 1)
    session$setInputs(fs_use_holidays = FALSE)
    session$setInputs(fs_finalize_holidays = 1)
    expect_null(final_holidays())
  })
})
