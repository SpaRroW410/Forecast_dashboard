test_that("reconcile_bottom_up sums yhat/yhat_lower/yhat_upper and train$y across groups by ds", {
  ds <- as.Date("2024-01-01") + 0:2
  fits <- list(
    A = list(fc_tib = tibble::tibble(ds = ds, yhat = c(10, 11, 12), yhat_lower = c(8, 9, 10), yhat_upper = c(12, 13, 14)),
              train = tibble::tibble(ds = ds, y = c(5, 6, 7))),
    B = list(fc_tib = tibble::tibble(ds = ds, yhat = c(1, 2, 3), yhat_lower = c(0, 1, 2), yhat_upper = c(2, 3, 4)),
              train = tibble::tibble(ds = ds, y = c(1, 1, 1)))
  )
  rec <- reconcile_bottom_up(fits)
  expect_equal(rec$fc_tib$yhat, c(11, 13, 15))
  expect_equal(rec$fc_tib$yhat_lower, c(8, 10, 12))
  expect_equal(rec$fc_tib$yhat_upper, c(14, 16, 18))
  expect_equal(rec$train$y, c(6, 7, 8))
  expect_setequal(rec$components, c("A", "B"))
})

test_that("reconcile_bottom_up drops a NULL entry rather than erroring, and errors on nothing at all", {
  ds <- as.Date("2024-01-01") + 0:1
  fits <- list(
    A = list(fc_tib = tibble::tibble(ds = ds, yhat = c(1, 2)), train = tibble::tibble(ds = ds, y = c(1, 2))),
    B = NULL
  )
  rec <- reconcile_bottom_up(fits)
  expect_equal(rec$components, "A")
  expect_equal(rec$fc_tib$yhat, c(1, 2))

  expect_error(reconcile_bottom_up(list(A = NULL)), "No fitted groups")
})

.recon_demo_data <- function() {
  set.seed(1)
  data.frame(
    Date = rep(seq.Date(as.Date("2021-01-01"), as.Date("2021-12-31"), by = "day"), 3),
    District = rep(c("A", "B", "C"), each = 365),
    Cases = c(stats::rpois(365, 20), stats::rpois(365, 10), stats::rpois(365, 5))
  )
}

test_that("'.reconciled' is only offered once >= 2 groups are fit, and never for a single-group subset", {
  main <- .recon_demo_data()
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_recon_test_df", main, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_recon_test_df")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "Date", fs_value_col = "Cases")
    session$setInputs(fs_date_agg = "month")
    session$setInputs(fs_group_col = "District")
    session$setInputs(fs_group_values = c("A", "B", "C"))
    session$setInputs(fs_finalize_data = 1)
    session$setInputs(fs_model_choice = "arima", fs_arima_mode = "auto")
    session$setInputs(fs_horizon_months = 3, fs_test_months = 2)

    session$setInputs(fs_fit_groups = "A")
    session$setInputs(fs_fit_btn = 1)
    html_one <- paste(as.character(output$fs_group_view_ui), collapse = "")
    expect_false(grepl(".reconciled", html_one, fixed = TRUE))

    session$setInputs(fs_fit_groups = c("A", "B"))
    session$setInputs(fs_fit_btn = 2)
    html_two <- paste(as.character(output$fs_group_view_ui), collapse = "")
    expect_true(grepl(".reconciled", html_two, fixed = TRUE))
  })
  rm("fs_recon_test_df", envir = globalenv())
})

test_that("active_fit() for '.reconciled' returns the right synthetic shape, exact sums, and a partial label", {
  main <- .recon_demo_data()
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_recon_test_df2", main, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_recon_test_df2")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "Date", fs_value_col = "Cases")
    session$setInputs(fs_date_agg = "month")
    session$setInputs(fs_group_col = "District")
    session$setInputs(fs_group_values = c("A", "B", "C"))
    session$setInputs(fs_finalize_data = 1)
    session$setInputs(fs_model_choice = "arima", fs_arima_mode = "auto")
    session$setInputs(fs_horizon_months = 3, fs_test_months = 2)

    session$setInputs(fs_fit_groups = c("A", "B"))  # partial: C not fit
    session$setInputs(fs_fit_btn = 1)
    session$setInputs(fs_group_view = ".reconciled")

    af <- active_fit()
    expect_true(isTRUE(af$reconciled))
    expect_null(af$model_obj)
    expect_setequal(af$components, c("A", "B"))
    expect_true(af$partial)

    gm <- grouped_fitted_models()
    manual_sum <- gm[["A"]]$fc_tib$yhat + gm[["B"]]$fc_tib$yhat
    expect_equal(af$fc_tib$yhat, manual_sum)

    args <- current_forecast_plot_args()
    expect_match(args$subtitle, "Bottom-up sum of 2 group")
    expect_match(args$subtitle, "partial: 2 of 3")

    # compute_multi_window_metrics() runs cleanly on the synthetic list
    m <- compute_multi_window_metrics(af$fc_tib, af$train, af$test, effective_date_agg())
    expect_true(is.data.frame(m))
  })
  rm("fs_recon_test_df2", envir = globalenv())
})

test_that("fitting every configured group makes the reconciled result non-partial", {
  main <- .recon_demo_data()
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_recon_test_df3", main, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_recon_test_df3")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "Date", fs_value_col = "Cases")
    session$setInputs(fs_date_agg = "month")
    session$setInputs(fs_group_col = "District")
    session$setInputs(fs_group_values = c("A", "B", "C"))
    session$setInputs(fs_finalize_data = 1)
    session$setInputs(fs_model_choice = "arima", fs_arima_mode = "auto")
    session$setInputs(fs_horizon_months = 3, fs_test_months = 2)

    session$setInputs(fs_fit_groups = c("A", "B", "C"))
    session$setInputs(fs_fit_btn = 1)
    session$setInputs(fs_group_view = ".reconciled")

    af <- active_fit()
    expect_false(af$partial)
    expect_setequal(af$components, c("A", "B", "C"))
  })
  rm("fs_recon_test_df3", envir = globalenv())
})

test_that("the ungrouped path is unaffected: active_fit() still equals fitted_model()", {
  df <- data.frame(when = as.Date("2024-01-01") + 0:59, val = stats::rpois(60, 10))
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_recon_ungrouped_df", df, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_recon_ungrouped_df")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "when", fs_value_col = "val")
    session$setInputs(fs_date_agg = "day")
    session$setInputs(fs_finalize_data = 1)
    session$setInputs(fs_model_choice = "arima", fs_arima_mode = "auto")
    session$setInputs(fs_horizon_months = 1, fs_test_months = 1)
    session$setInputs(fs_fit_btn = 1)

    expect_null(grouped_series())
    expect_identical(active_fit()$key, fitted_model()$key)
    expect_identical(active_fit()$fc_tib, fitted_model()$fc_tib)
  })
  rm("fs_recon_ungrouped_df", envir = globalenv())
})
