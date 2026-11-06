# End-to-end smoke test of the hosted app in a headless browser, replaying
# the demo-data flow that previously crashed or misbehaved:
#   * "Final holiday list finalized" appeared on the Data tab at start-up
#   * Holidays -> Apply Window Settings disconnected the session
#   * the default forecast failed on the demo data with a cryptic error
#   * forecasting needed a finalized holiday list even with holidays off

skip_on_cran()
skip_if_not_installed("shinytest2")
skip_if(is.null(tryCatch(chromote::find_chrome(), error = function(e) NULL)), "Chrome not available")

notifications <- function(app) {
  app$get_js("Array.from(document.querySelectorAll('.shiny-notification-content-text')).map(e => e.innerText).join(' | ')")
}
clear_notifications <- function(app) {
  app$run_js("document.querySelectorAll('.shiny-notification').forEach(n => n.remove());")
}
connected <- function(app) {
  isTRUE(app$get_js("!document.getElementById('shiny-disconnected-overlay') && Shiny.shinyapp.isConnected()"))
}

test_that("demo data flows through import, holidays, Prophet, ARIMA and SARIMA without errors", {
  app <- shinytest2::AppDriver$new(app_dir, name = "smoke", load_timeout = 120 * 1000,
                                   timeout = 120 * 1000, seed = 1)
  withr::defer(app$stop())

  # ---- Import the bundled demo dataset through the datamods file importer
  app$click("main-main_import_btn")
  app$click("main-method_file")
  app$wait_for_idle()
  app$upload_file(`main-file-import-file-file` = file.path(app_dir, "data", "daily-total-female-births.csv"))
  app$click("main-file-import-confirm")
  app$set_inputs(data_type = "agg")
  app$set_inputs(model_date_col = "Date", model_value_col = "Births")
  app$click("transform_main")
  clear_notifications(app)
  app$click("process_data")
  app$wait_for_idle()

  # Regression: holidays must not be auto-"finalized" when the dataset is processed.
  expect_false(grepl("in use for forecasting", notifications(app), fixed = TRUE))
  expect_match(app$get_text("#final_holiday_status"), "No holiday list in use", fixed = TRUE)

  # ---- Forecast with NO holidays configured and default settings.
  # The demo data is exactly 12 months long, so the default 12-month test
  # window leaves nothing to train on: expect a clear message, not a crash.
  app$set_inputs(main_tabs = "forecast_tab")
  clear_notifications(app)
  app$click("forecast_btn")
  app$wait_for_idle()
  expect_match(notifications(app), "covers all of your data", fixed = TRUE)
  expect_true(connected(app))

  # A shorter test window fits, without needing a finalized holiday list.
  app$set_inputs(manual_test_months = 3)
  clear_notifications(app)
  app$click("forecast_btn")
  app$wait_for_idle(timeout = 180 * 1000)
  # (The 6-second "without holiday effects" toast may already have expired
  # here; a rendered plot with no failure message is the real check.)
  expect_false(grepl("failed", notifications(app), fixed = TRUE))
  expect_true(nzchar(app$get_js("document.querySelector('#forecastPlot img')?.src || ''")))

  # ---- Holidays: build a list, then Apply Window Settings (used to disconnect).
  app$set_inputs(main_tabs = "holiday_tab")
  app$set_inputs(use_holiday_effects = "yes")
  app$click("compile_fixed_holidays")
  app$wait_for_idle()
  app$run_js("$('.modal').modal('hide');")

  # A positive "days before" is rejected with a clear message (Prophet needs <= 0).
  clear_notifications(app)
  app$set_inputs(window_label = "Sunday", lower_window = 2, upper_window = 0)
  app$click("apply_window")
  app$wait_for_idle()
  expect_match(notifications(app), "0 or negative", fixed = TRUE)

  app$set_inputs(window_label = "Sunday", lower_window = -1, upper_window = 0)
  app$click("apply_window")
  app$wait_for_idle()
  expect_true(connected(app))

  # Use the list for forecasting, then forecast with holidays.
  clear_notifications(app)
  app$click("confirm_finalize")
  app$wait_for_idle()
  expect_match(notifications(app), "in use for forecasting", fixed = TRUE)
  expect_match(app$get_text("#final_holiday_status"), "In use for forecasting", fixed = TRUE)
  app$set_inputs(main_tabs = "forecast_tab")
  clear_notifications(app)
  app$click("forecast_btn")
  app$wait_for_idle(timeout = 180 * 1000)
  expect_false(grepl("failed", notifications(app), fixed = TRUE))
  expect_true(connected(app))

  # ---- ARIMA and SARIMA
  app$set_inputs(main_tabs = "arima_tab")
  app$click("fit_arima")
  app$wait_for_idle(timeout = 180 * 1000)
  expect_match(app$get_text("#arima_summary"), "ARIMA", fixed = TRUE)
  app$set_inputs(main_tabs = "sarima_tab")
  app$click("fit_sarima")
  app$wait_for_idle(timeout = 180 * 1000)
  expect_match(app$get_text("#sarima_summary"), "ARIMA", fixed = TRUE)
  expect_true(connected(app))

  # No uncaught server errors in the R log.
  logs <- paste(format(app$get_logs()), collapse = "\n")
  expect_false(grepl("Warning: Error in", logs, fixed = TRUE))
})
