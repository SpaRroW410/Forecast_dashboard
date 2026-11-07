# End-to-end smoke test of the hosted app in a headless browser, replaying
# the demo-data flow that previously crashed or misbehaved:
#   * "Final holiday list finalized" appeared on the Data tab at start-up
#   * Holidays -> Apply Window Settings disconnected the session
#   * the default forecast failed on the demo data with a cryptic error
#   * forecasting needed a finalized holiday list even with holidays off

skip_on_cran()
skip_if_not_installed("shinytest2")

# Start Chrome up front. Locally a missing Chrome just skips this test, but CI
# sets REQUIRE_SMOKE_TEST=true so the run FAILS instead: shinytest2 otherwise
# turns a Chrome start-up failure into a silent skip and a green run.
start_chrome <- function() {
  tryCatch({
    chromote::set_default_chromote_object(chromote::Chromote$new())
    TRUE
  }, error = function(e) {
    message("Chrome could not be started: ", conditionMessage(e))
    FALSE
  })
}

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
  if (!start_chrome()) {
    if (identical(Sys.getenv("REQUIRE_SMOKE_TEST"), "true")) {
      stop("Chrome could not be started and REQUIRE_SMOKE_TEST=true: refusing to skip the browser smoke test.")
    }
    skip("Chrome not available")
  }
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

  # Hidden tabs must not render until visited (Shiny's output suspension).
  # A custom tab-fade CSS rule (display:block on inactive panes) used to make
  # every tab render eagerly, e.g. the ARIMA/SARIMA tables while the user
  # was still on the Data tab.
  expect_equal(app$get_js("document.querySelectorAll('#arima_data_preview tbody tr').length"), 0)
  expect_equal(app$get_js("document.querySelectorAll('#sarima_data_preview tbody tr').length"), 0)

  # Regression: holidays must not be auto-"finalized" when the dataset is processed.
  expect_false(grepl("in use for forecasting", notifications(app), fixed = TRUE))
  # (Outputs on hidden tabs no longer render until opened, so open Step 4 first.)
  app$set_inputs(main_tabs = "holiday_tab")
  app$set_inputs(holiday_main_tabs = "Step 4 · Review & use")
  app$wait_for_idle()
  expect_match(app$get_text("#final_holiday_status"), "No holiday list in use", fixed = TRUE)

  # ---- Forecast with NO holidays configured and default settings.
  # The demo data is exactly 12 months long, so the default 12-month test
  # window leaves nothing to train on: expect a clear message, not a crash.
  app$set_inputs(main_tabs = "forecast_tab")

  # Buttons that need a forecast say so instead of silently doing nothing.
  clear_notifications(app)
  app$click("eval_btn")
  app$wait_for_idle()
  expect_match(notifications(app), "Generate a forecast first", fixed = TRUE)

  # Hourly data: a clear message (this used to end the session).
  app$set_inputs(date_agg = "hour")
  clear_notifications(app)
  app$click("forecast_btn")
  app$wait_for_idle()
  expect_match(notifications(app), "For hourly data use the ARIMA or SARIMA tab", fixed = TRUE)
  expect_true(connected(app))
  app$set_inputs(date_agg = "day")

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
  app$set_inputs(holiday_main_tabs = "Step 1 · Import & fixed")
  app$set_inputs(use_holiday_effects = "yes")

  # Import the example holiday file. The name picker must default to the
  # second column (it used to default to the date column, naming holidays
  # after their dates), and a non-date "date" column must give a message
  # instead of ending the session.
  app$click("hol-main_import_btn")
  app$click("hol-method_file")
  app$wait_for_idle()
  app$upload_file(`hol-file-import-file-file` = file.path(app_dir, "data", "example_holidays.csv"))
  app$click("hol-file-import-confirm")
  app$wait_for_idle()
  expect_equal(app$get_value(input = "label_col"), "holiday_name")
  clear_notifications(app)
  app$set_inputs(date_col = "holiday_name")
  app$click("finalize_movable")
  app$wait_for_idle()
  expect_match(notifications(app), "could not be read as dates", fixed = TRUE)
  expect_true(connected(app))
  app$set_inputs(date_col = "date")
  app$click("finalize_movable")
  app$wait_for_idle()
  app$run_js("$('.modal').modal('hide');")

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
  app$set_inputs(holiday_main_tabs = "Step 4 · Review & use")
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

  # No uncaught server errors in the R log, and no uncaught JavaScript
  # exceptions in the browser (shinyBS's Bootstrap-3 tooltip used to throw
  # 'No method named "destroy"' under Bootstrap 5 on every page load).
  logs <- as.data.frame(app$get_logs())
  expect_false(any(grepl("Warning: Error in", logs$message, fixed = TRUE)))

  # Key events are logged for the deployment log.
  all_logs <- paste(logs$message, collapse = "\n")
  for (event in c("start-up: R version", "session started", "dataset processed: 365 rows",
                  "forecast fitted in", "holiday list in use", "ARIMA fitted in", "SARIMA fitted in")) {
    expect_match(all_logs, event, fixed = TRUE)
  }
  js_errors <- logs$message[logs$location == "chromote" & logs$level %in% c("throw", "error")]
  expect_equal(js_errors, character(0))
})
