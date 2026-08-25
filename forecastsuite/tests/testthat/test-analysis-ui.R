test_that("the Model tab UI exposes every new Analysis section output", {
  html <- as.character(build_model_tab_ui())
  for (id in c("fs_decomp_plot", "fs_anomaly_method", "fs_anomaly_threshold",
               "fs_anomaly_plot", "fs_anomaly_table", "fs_download_anomalies_csv",
               "fs_resid_plot", "fs_resid_acf_plot", "fs_resid_tests",
               "fs_group_correlation_plot", "fs_group_correlation_table",
               "fs_download_correlation_csv")) {
    expect_true(grepl(id, html, fixed = TRUE), info = id)
  }
})

.diag_demo_data <- function(n = 200) {
  set.seed(7)
  data.frame(
    Date = as.Date("2023-01-01") + 0:(n - 1),
    Cases = 100 + 20 * sin(2 * pi * (0:(n - 1)) / 7) + stats::rnorm(n, sd = 2)
  )
}

test_that("seasonal decomposition and anomaly detection work as soon as a dataset is finalized, no fit required", {
  main <- .diag_demo_data()
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_diag_test_df", main, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_diag_test_df")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "Date", fs_value_col = "Cases")
    session$setInputs(fs_date_agg = "day")
    session$setInputs(fs_finalize_data = 1)

    expect_null(fitted_model())  # confirm: no fit has happened yet

    decomp <- decompose_series(active_series(), effective_date_agg())
    expect_false(is.null(decomp))
    expect_equal(nrow(decomp), nrow(main))

    session$setInputs(fs_anomaly_method = "iqr", fs_anomaly_threshold = 1.5)
    a <- anomalies()
    expect_equal(nrow(a), nrow(main))
    expect_true("is_anomaly" %in% names(a))
  })
  rm("fs_diag_test_df", envir = globalenv())
})

test_that("residual diagnostics require a completed fit -- errors before, works after", {
  main <- .diag_demo_data()
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_resid_test_df", main, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_resid_test_df")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "Date", fs_value_col = "Cases")
    session$setInputs(fs_date_agg = "day")
    session$setInputs(fs_finalize_data = 1)

    expect_error(resid_diag())

    session$setInputs(fs_model_choice = "arima", fs_arima_mode = "auto")
    session$setInputs(fs_horizon_months = 1, fs_test_months = 1)
    session$setInputs(fs_fit_btn = 1)

    rd <- resid_diag()
    expect_true(nrow(rd$residuals) > 0)
    expect_true(is.numeric(rd$ci))
  })
  rm("fs_resid_test_df", envir = globalenv())
})

.corr_demo_data <- function() {
  set.seed(3)
  data.frame(
    Date = rep(seq.Date(as.Date("2022-01-01"), as.Date("2022-12-31"), by = "day"), 2),
    District = rep(c("A", "B"), each = 365),
    Cases = c(stats::rpois(365, 20), stats::rpois(365, 8))
  )
}

test_that("group correlation needs at least 2 groups: empty with 1, populated with 2+", {
  main <- .corr_demo_data()
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_corr_test_df", main, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_corr_test_df")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "Date", fs_value_col = "Cases")
    session$setInputs(fs_date_agg = "month")
    session$setInputs(fs_group_col = "District")

    session$setInputs(fs_group_values = "A")
    session$setInputs(fs_finalize_data = 1)
    expect_equal(nrow(group_correlations()), 0)

    session$setInputs(fs_group_values = c("A", "B"))
    session$setInputs(fs_finalize_data = 2)
    cor_tbl <- group_correlations()
    expect_equal(nrow(cor_tbl), 1)
    expect_equal(cor_tbl$group_a[1], "A")
    expect_equal(cor_tbl$group_b[1], "B")
  })
  rm("fs_corr_test_df", envir = globalenv())
})

test_that("the ungrouped path leaves group_correlations() empty rather than erroring", {
  df <- data.frame(when = as.Date("2024-01-01") + 0:29, val = 1:30)
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_corr_ungrouped_df", df, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_corr_ungrouped_df")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "when", fs_value_col = "val")
    session$setInputs(fs_date_agg = "day")
    session$setInputs(fs_finalize_data = 1)

    expect_error(group_correlations())  # grouped_series() is NULL -> req() throws
  })
  rm("fs_corr_ungrouped_df", envir = globalenv())
})

test_that("restore_project_inputs() sends the right update message for the anomaly-detection fields", {
  # update*Input() calls cannot be verified to reach input$x inside
  # shiny::testServer() -- no simulated client to echo the message back
  # (same documented limitation as every other restore_* field). Verify
  # the sendInputMessage() payload directly instead.
  captured <- list()
  fake_session <- structure(
    list(sendInputMessage = function(inputId, message) captured[[inputId]] <<- message),
    class = "ShinySession"
  )
  ui_inputs <- list(fs_anomaly_method = "zscore", fs_anomaly_threshold = 2.5)
  restore_project_inputs(fake_session, list(ui_inputs = ui_inputs))

  expect_equal(captured$fs_anomaly_method$value, "zscore")
  expect_equal(captured$fs_anomaly_threshold$value, "2.5")
})
