test_that("build_project_payload never includes fitted-model-shaped content", {
  payload <- build_project_payload(
    final_dataset = tibble::tibble(ds = as.Date("2024-01-01"), y = 1),
    grouped_series = NULL, effective_group_col = NULL, effective_date_agg = "day",
    holidays_compiled = tibble::tibble(ds = as.Date(character()), holiday = character()),
    holidays_windows = tibble::tibble(holiday = character(), lower_window = integer(), upper_window = integer()),
    holidays_final = NULL,
    ui_inputs = list(fs_model_choice = "arima")
  )
  expect_equal(payload$schema_version, 1L)
  expect_false("fitted_model" %in% names(payload))
  expect_false("grouped_fitted_models" %in% names(payload))
  expect_false("model_obj" %in% names(payload))
  expect_setequal(names(payload),
                   c("schema_version", "saved_at", "final_dataset", "grouped_series",
                     "effective_group_col", "effective_date_agg", "holidays_compiled",
                     "holidays_windows", "holidays_final", "ui_inputs"))
})

test_that("restore_project_inputs sends the correct update message for every restorable field", {
  # update*Input() functions are thin wrappers over session$sendInputMessage()
  # -- no live Shiny reactive context/testServer client-echo needed to test
  # this correctly, and testServer's mock session can't echo updates back
  # into input$x anyway (a documented framework limitation, not a bug).
  captured <- list()
  fake_session <- structure(
    list(sendInputMessage = function(inputId, message) captured[[inputId]] <<- message),
    class = "ShinySession"
  )
  payload <- list(ui_inputs = list(
    fs_model_choice = "sarima", fs_horizon_months = 6, fs_test_months = 3,
    fs_show_trend = FALSE, fs_show_uncertainty = TRUE,
    fs_color_actual = "#111111", fs_color_forecast = "#123456",
    fs_p = 2, fs_d = 1, fs_q = 0, fs_cv_folds = 5,
    fs_holiday_years = c(2020, 2025), fs_use_holidays = TRUE
  ))
  restore_project_inputs(fake_session, payload)

  expect_equal(captured[["fs_model_choice"]]$value, "sarima")
  expect_equal(captured[["fs_horizon_months"]]$value, "6")
  expect_equal(captured[["fs_test_months"]]$value, "3")
  expect_equal(captured[["fs_show_trend"]]$value, FALSE)
  expect_equal(captured[["fs_show_uncertainty"]]$value, TRUE)
  expect_equal(captured[["fs_color_actual"]]$value, "#111111")
  expect_equal(captured[["fs_color_forecast"]]$value, "#123456")
  expect_equal(captured[["fs_p"]]$value, "2")
  expect_equal(captured[["fs_cv_folds"]]$value, "5")
  expect_equal(captured[["fs_use_holidays"]]$value, TRUE)
})

test_that("restore_project_inputs skips fields absent from ui_inputs rather than sending a message", {
  captured <- list()
  fake_session <- structure(
    list(sendInputMessage = function(inputId, message) captured[[inputId]] <<- message),
    class = "ShinySession"
  )
  restore_project_inputs(fake_session, list(ui_inputs = list(fs_model_choice = "ets")))
  expect_equal(names(captured), "fs_model_choice")

  # NULL/missing ui_inputs is a no-op, not an error
  expect_silent(restore_project_inputs(fake_session, list()))
})

.proj_demo_data <- function() {
  set.seed(1)
  data.frame(
    Date = rep(seq.Date(as.Date("2021-01-01"), as.Date("2021-12-31"), by = "day"), 2),
    District = rep(c("A", "B"), each = 365),
    Cases = c(stats::rpois(365, 20), stats::rpois(365, 10))
  )
}

test_that("a full save-then-load round trip restores the dataset, grouping, and holidays exactly", {
  main <- .proj_demo_data()
  payload_path <- tempfile(fileext = ".rds")
  saved_agg_rows <- NULL
  saved_group_names <- NULL
  saved_holiday_rows <- NULL

  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_proj_test_df", main, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_proj_test_df")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "Date", fs_value_col = "Cases")
    session$setInputs(fs_date_agg = "month")
    session$setInputs(fs_group_col = "District")
    session$setInputs(fs_group_values = c("A", "B"))
    session$setInputs(fs_finalize_data = 1)

    session$setInputs(fs_use_holidays = TRUE)
    session$setInputs(fs_holiday_years = c(2021, 2021), fs_include_sundays = TRUE)
    session$setInputs(fs_generate_fixed = 1)

    payload <- build_project_payload(
      final_dataset = final_dataset(), grouped_series = grouped_series(),
      effective_group_col = effective_group_col(), effective_date_agg = effective_date_agg(),
      holidays_compiled = combined_holidays(), holidays_windows = holiday_state$windows(),
      holidays_final = final_holidays(),
      ui_inputs = list(fs_model_choice = "sarima", fs_horizon_months = 6, fs_test_months = 3)
    )
    saveRDS(payload, payload_path)

    saved_agg_rows <<- nrow(final_dataset())
    saved_group_names <<- names(grouped_series())
    saved_holiday_rows <<- nrow(combined_holidays())
  })
  rm("fs_proj_test_df", envir = globalenv())

  # Fresh session, NO prior import step at all.
  shiny::testServer(build_app_server, {
    expect_null(final_dataset())
    expect_null(grouped_series())

    session$setInputs(fs_project_file = list(datapath = payload_path, name = "p.rds"))

    expect_equal(nrow(final_dataset()), saved_agg_rows)
    expect_setequal(names(grouped_series()), saved_group_names)
    expect_equal(effective_group_col(), "District")
    expect_equal(effective_date_agg(), "month")
    expect_equal(nrow(combined_holidays()), saved_holiday_rows)
    expect_null(fitted_model())
    expect_null(grouped_fitted_models())

    # Fit & Forecast works immediately post-load, with no re-import. As
    # elsewhere in this suite, fs_horizon_months/fs_test_months are set
    # explicitly here rather than relying on restore_project_inputs()'s
    # updateSliderInput() calls to have taken effect: testServer has no
    # simulated client to echo an update*Input() message back into
    # input$x (see the fake-session unit test above, which verifies the
    # correct message is sent -- that's the part this package's code
    # actually controls).
    session$setInputs(fs_model_choice = "arima", fs_arima_mode = "auto")
    session$setInputs(fs_horizon_months = 3, fs_test_months = 2)
    session$setInputs(fs_fit_groups = c("A", "B"))
    session$setInputs(fs_fit_btn = 1)
    expect_setequal(names(grouped_fitted_models()), c("A", "B"))
  })
})

test_that("loading a file that isn't a forecastsuite project is rejected without crashing", {
  bad_path <- tempfile(fileext = ".rds")
  saveRDS(list(not_a = "project"), bad_path)

  shiny::testServer(build_app_server, {
    session$setInputs(fs_project_file = list(datapath = bad_path, name = "bad.rds"))
    expect_null(final_dataset())
  })
})

test_that("holidays_server_logic's return list includes windows alongside compiled/final", {
  main <- .proj_demo_data()
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_proj_test_df2", main, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_proj_test_df2")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "Date", fs_value_col = "Cases")
    session$setInputs(fs_date_agg = "day")
    session$setInputs(fs_finalize_data = 1)

    session$setInputs(fs_use_holidays = TRUE)
    session$setInputs(fs_holiday_years = c(2021, 2021), fs_include_sundays = TRUE)
    session$setInputs(fs_generate_fixed = 1)
    session$setInputs(fs_window_label = "Sunday")
    session$setInputs(fs_lower_window = 1, fs_upper_window = 1)
    session$setInputs(fs_apply_window = 1)

    expect_gt(nrow(holiday_state$windows()), 0)
  })
  rm("fs_proj_test_df2", envir = globalenv())
})
