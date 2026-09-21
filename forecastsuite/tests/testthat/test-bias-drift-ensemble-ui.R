.bde_demo_data <- function(n = 60) {
  set.seed(3)
  data.frame(
    Date = as.Date("2023-01-01") + 0:(n - 1),
    Cases = 100 + seq_len(n) * 0.2 + stats::rnorm(n, sd = 1)
  )
}

test_that("the Model tab UI exposes the Bias & Drift and ensemble/leaderboard controls", {
  html <- as.character(build_model_tab_ui())
  for (id in c("fs_bias_drift_table", "fs_bias_drift_read",
               "fs_ensemble_method", "fs_build_ensemble",
               "fs_run_leaderboard", "fs_leaderboard_table")) {
    expect_true(grepl(id, html, fixed = TRUE), info = id)
  }
})

test_that("bias/drift requires a completed fit -- errors before, works after", {
  main <- .bde_demo_data()
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_bde_test_df", main, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_bde_test_df")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "Date", fs_value_col = "Cases")
    session$setInputs(fs_date_agg = "day")
    session$setInputs(fs_finalize_data = 1)

    expect_error(bias_drift_result())

    session$setInputs(fs_model_choice = "arima", fs_arima_mode = "auto")
    session$setInputs(fs_horizon_months = 1, fs_test_months = 1)
    session$setInputs(fs_fit_btn = 1)

    bd <- bias_drift_result()
    expect_true(nrow(bd$chunks) > 0)
  })
  rm("fs_bde_test_df", envir = globalenv())
})

test_that("building an ensemble from >=2 compared models appends 'Ensemble' to the comparison plot/table", {
  main <- .bde_demo_data(90)
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_ensemble_test_df", main, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_ensemble_test_df")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "Date", fs_value_col = "Cases")
    session$setInputs(fs_date_agg = "day")
    session$setInputs(fs_finalize_data = 1)
    session$setInputs(fs_horizon_months = 1, fs_test_months = 1)

    session$setInputs(fs_compare_choices = c("arima", "ets"))
    session$setInputs(fs_compare_btn = 1)
    expect_false("Ensemble" %in% names(comparison_forecasts()))

    session$setInputs(fs_ensemble_method = "mean")
    session$setInputs(fs_build_ensemble = 1)

    fcs <- comparison_forecasts()
    expect_true("Ensemble" %in% names(fcs))
    expect_true("Ensemble" %in% comparison_result()$Set)
  })
  rm("fs_ensemble_test_df", envir = globalenv())
})

test_that("building an ensemble with fewer than 2 compared models shows an error, not a crash", {
  main <- .bde_demo_data(90)
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_ensemble_test_df2", main, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_ensemble_test_df2")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "Date", fs_value_col = "Cases")
    session$setInputs(fs_date_agg = "day")
    session$setInputs(fs_finalize_data = 1)
    session$setInputs(fs_horizon_months = 1, fs_test_months = 1)

    session$setInputs(fs_compare_choices = "arima")
    session$setInputs(fs_compare_btn = 1)

    expect_no_error(session$setInputs(fs_build_ensemble = 1))
    expect_false("Ensemble" %in% names(comparison_forecasts()))
  })
  rm("fs_ensemble_test_df2", envir = globalenv())
})
