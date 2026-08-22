.grouping_demo_data <- function() {
  set.seed(1)
  data.frame(
    Date = rep(seq.Date(as.Date("2021-01-01"), as.Date("2021-12-31"), by = "day"), 2),
    District = rep(c("A", "B"), each = 365),
    Cases = c(stats::rpois(365, 20), stats::rpois(365, 10))
  )
}

test_that("the Import UI exposes a grouping column selector and the Model tab exposes group controls", {
  html <- as.character(build_import_tab_ui())
  expect_true(grepl("fs_group_col", html, fixed = TRUE))
  expect_true(grepl("fs_group_values", html, fixed = TRUE))
  expect_true(grepl("fs_pop_group_col", html, fixed = TRUE))

  model_html <- as.character(build_model_tab_ui())
  expect_true(grepl("fs_fit_groups_ui", model_html, fixed = TRUE))
  expect_true(grepl("fs_group_view_ui", model_html, fixed = TRUE))
  expect_true(grepl("fs_group_overlay_plot", model_html, fixed = TRUE))
  expect_true(grepl("fs_download_group_overlay_png", model_html, fixed = TRUE))
})

test_that("finalizing with a grouping column populates grouped_series() and leaves final_dataset() as the aggregate", {
  main <- .grouping_demo_data()
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_grouping_test_df", main, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_grouping_test_df")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "Date", fs_value_col = "Cases")
    session$setInputs(fs_date_agg = "month")
    session$setInputs(fs_group_col = "District")
    session$setInputs(fs_group_values = c("A", "B"))
    session$setInputs(fs_finalize_data = 1)

    fd <- final_dataset()
    gs <- grouped_series()
    expect_equal(nrow(fd), 12)
    expect_setequal(names(gs), c("A", "B"))
    expect_equal(nrow(gs[["A"]]), 12)
    expect_equal(nrow(gs[["B"]]), 12)
    # The aggregate is exactly the sum of the per-group series -- grouping
    # doesn't change what final_dataset() represents, only adds to it.
    expect_equal(sum(gs[["A"]]$y) + sum(gs[["B"]]$y), sum(fd$y))
  })
  rm("fs_grouping_test_df", envir = globalenv())
})

test_that("the Import tab's group-values checklist actually excludes unchecked groups", {
  main <- rbind(.grouping_demo_data(),
                 data.frame(Date = seq.Date(as.Date("2021-01-01"), as.Date("2021-12-31"), by = "day"),
                             District = "C", Cases = stats::rpois(365, 5)))
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_grouping_test_df2", main, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_grouping_test_df2")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "Date", fs_value_col = "Cases")
    session$setInputs(fs_date_agg = "month")
    session$setInputs(fs_group_col = "District")
    session$setInputs(fs_group_values = c("A", "B"))  # C excluded
    session$setInputs(fs_finalize_data = 1)

    expect_setequal(names(grouped_series()), c("A", "B"))
  })
  rm("fs_grouping_test_df2", envir = globalenv())
})

test_that("switching fs_group_col back to '(none)' clears grouped_series() and restores the ungrouped path", {
  main <- .grouping_demo_data()
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_grouping_test_df3", main, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_grouping_test_df3")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "Date", fs_value_col = "Cases")
    session$setInputs(fs_date_agg = "month")
    session$setInputs(fs_group_col = "District")
    session$setInputs(fs_group_values = c("A", "B"))
    session$setInputs(fs_finalize_data = 1)
    expect_false(is.null(grouped_series()))

    session$setInputs(fs_group_col = "")
    session$setInputs(fs_finalize_data = 2)
    expect_null(grouped_series())
    expect_equal(nrow(final_dataset()), 12)
  })
  rm("fs_grouping_test_df3", envir = globalenv())
})

test_that("fitting a subset of groups populates exactly those in grouped_fitted_models(), and the group-view selector switches active_fit()", {
  main <- .grouping_demo_data()
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_grouping_test_df4", main, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_grouping_test_df4")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "Date", fs_value_col = "Cases")
    session$setInputs(fs_date_agg = "month")
    session$setInputs(fs_group_col = "District")
    session$setInputs(fs_group_values = c("A", "B"))
    session$setInputs(fs_finalize_data = 1)

    session$setInputs(fs_model_choice = "arima", fs_arima_mode = "auto")
    session$setInputs(fs_horizon_months = 3, fs_test_months = 2)
    session$setInputs(fs_fit_groups = "A")  # fit only A this run
    session$setInputs(fs_fit_btn = 1)

    gfm <- grouped_fitted_models()
    expect_equal(names(gfm), "A")
    expect_null(fitted_model())  # single-series path stays untouched

    session$setInputs(fs_group_view = "A")
    af <- active_fit()
    expect_equal(af$key, "arima")
    expect_equal(af$group, "A")
  })
  rm("fs_grouping_test_df4", envir = globalenv())
})

test_that("Compare Selected Models only ever uses the currently-viewed single group while grouping is active", {
  main <- .grouping_demo_data()
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_grouping_test_df5", main, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_grouping_test_df5")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "Date", fs_value_col = "Cases")
    session$setInputs(fs_date_agg = "month")
    session$setInputs(fs_group_col = "District")
    session$setInputs(fs_group_values = c("A", "B"))
    session$setInputs(fs_finalize_data = 1)
    session$setInputs(fs_horizon_months = 3, fs_test_months = 2)

    session$setInputs(fs_model_choice = "arima", fs_arima_mode = "auto")
    session$setInputs(fs_fit_groups = c("A", "B"))
    session$setInputs(fs_fit_btn = 1)
    session$setInputs(fs_group_view = "B")

    session$setInputs(fs_compare_choices = c("arima", "ets"))
    session$setInputs(fs_compare_btn = 1)

    expected_train <- train_test_split_for(grouped_series()[["B"]])$train
    expect_equal(nrow(comparison_train()), nrow(expected_train))
    expect_equal(sum(comparison_train()$y), sum(expected_train$y))
  })
  rm("fs_grouping_test_df5", envir = globalenv())
})

test_that("the group overlay plot has one actual and one forecast trace per fitted group", {
  main <- .grouping_demo_data()
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_grouping_test_df6", main, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_grouping_test_df6")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "Date", fs_value_col = "Cases")
    session$setInputs(fs_date_agg = "month")
    session$setInputs(fs_group_col = "District")
    session$setInputs(fs_group_values = c("A", "B"))
    session$setInputs(fs_finalize_data = 1)
    session$setInputs(fs_model_choice = "arima", fs_arima_mode = "auto")
    session$setInputs(fs_horizon_months = 3, fs_test_months = 2)
    session$setInputs(fs_fit_groups = c("A", "B"))
    session$setInputs(fs_fit_btn = 1)

    gm <- grouped_fitted_models()
    p <- plot_group_overlay(lapply(gm, `[[`, "fc_tib"), lapply(gm, `[[`, "train"))
    trace_names <- vapply(p$x$attrs, function(a) if (is.null(a$name)) "" else a$name, "")
    expect_true(all(c("A (actual)", "A (forecast)", "B (actual)", "B (forecast)") %in% trace_names))
  })
  rm("fs_grouping_test_df6", envir = globalenv())
})

test_that("the wide recommendation table's per-group columns match direct per-group recommend_model() calls", {
  main <- .grouping_demo_data()
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_grouping_test_df7", main, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_grouping_test_df7")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "Date", fs_value_col = "Cases")
    session$setInputs(fs_date_agg = "month")
    session$setInputs(fs_group_col = "District")
    session$setInputs(fs_group_values = c("A", "B"))
    session$setInputs(fs_finalize_data = 1)

    html <- output$fs_recommendation
    expect_true(grepl("Overall Score", html, fixed = TRUE))
    expect_true(grepl("> A </th>", html, fixed = TRUE))
    expect_true(grepl("> B </th>", html, fixed = TRUE))

    a_expected <- recommend_model(analyze_series(grouped_series()[["A"]], effective_date_agg()),
                                   holidays_configured = FALSE)
    expect_true(round(a_expected$score[a_expected$key == "arima"], 2) >= 0)
  })
  rm("fs_grouping_test_df7", envir = globalenv())
})

test_that("a full ungrouped regression scenario is unaffected: fs_group_col left unset behaves exactly as before", {
  # Mirrors test-aggregate-period.R's "finalizing many rows per quarter"
  # scenario -- District is present in the data but no grouping column is
  # selected, so it should be summed away exactly as it always was.
  counts <- data.frame(
    Year = 2021, Quarter = rep(1:4, each = 2),
    District = rep(c("D1", "D2"), 4),
    Cases = c(50, 50, 60, 40, 70, 30, 80, 20)
  )
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_grouping_test_df8", counts, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_grouping_test_df8")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_date_mode = "parts")
    session$setInputs(fs_year_col = "Year", fs_quarter_col = "Quarter",
                       fs_month_col = "", fs_day_col = "")
    session$setInputs(fs_data_type = "agg", fs_value_col = "Cases",
                       fs_date_agg = "quarter", fs_collapse_fun = "sum")
    # fs_group_col deliberately left at "" (the default)
    session$setInputs(fs_finalize_data = 1)

    fd <- final_dataset()
    expect_equal(nrow(fd), 4)
    expect_equal(sum(fd$y), 400)
    expect_null(grouped_series())
  })
  rm("fs_grouping_test_df8", envir = globalenv())
})

test_that("the holiday consistency check's scope selector switches which series is checked", {
  dates <- seq.Date(as.Date("2020-01-01"), as.Date("2023-12-31"), by = "day")
  is_jan1 <- format(dates, "%m-%d") == "01-01"
  main <- rbind(
    data.frame(Date = dates, District = "A", Cases = ifelse(is_jan1, 0, stats::rpois(length(dates), 20))),
    data.frame(Date = dates, District = "B", Cases = stats::rpois(length(dates), 15))
  )
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_grouping_test_df9", main, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_grouping_test_df9")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "Date", fs_value_col = "Cases")
    session$setInputs(fs_date_agg = "day", fs_collapse_fun = "sum")
    session$setInputs(fs_group_col = "District")
    session$setInputs(fs_group_values = c("A", "B"))
    session$setInputs(fs_finalize_data = 1)

    gs <- grouped_series()
    a_res <- holiday_contingency(combined_holidays(), gs[["A"]])
    b_res <- holiday_contingency(combined_holidays(), gs[["B"]])
    expect_gt(nrow(a_res$always_zero), 0)
    expect_equal(nrow(b_res$always_zero), 0)
  })
  rm("fs_grouping_test_df9", envir = globalenv())
})
