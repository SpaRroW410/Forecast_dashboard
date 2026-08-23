# One .rds payload = everything needed to resume forecasting work
# without re-importing or re-configuring, but deliberately NOT the
# fitted models themselves: Prophet's fitted objects carry a Stan
# external pointer that is a known R/Stan gotcha not guaranteed to
# survive a saveRDS()/readRDS() round-trip into a fresh R session, so
# restoring fits silently could produce a confusing failure later
# rather than an obvious one up front. After loading, the user re-runs
# Fit & Forecast (and Run Cross-Validation / group fitting) themselves.
# saveRDS()/readRDS() only -- no new dependency for this.
build_project_payload <- function(final_dataset, grouped_series, effective_group_col,
                                   effective_date_agg, holidays_compiled, holidays_windows,
                                   holidays_final, ui_inputs) {
  list(
    schema_version = 1L,
    saved_at = Sys.time(),
    final_dataset = final_dataset,
    grouped_series = grouped_series,
    effective_group_col = effective_group_col,
    effective_date_agg = effective_date_agg,
    holidays_compiled = holidays_compiled,
    holidays_windows = holidays_windows,
    holidays_final = holidays_final,
    ui_inputs = ui_inputs
  )
}

# Fires the matching updateXXXInput() for every field in payload$ui_inputs.
# A missing field (e.g. an older schema_version, or a field that was NULL
# when saved) is simply skipped rather than erroring -- every value here
# is optional restoration, never required for the app to keep working.
restore_project_inputs <- function(session, payload) {
  ui <- payload$ui_inputs
  if (is.null(ui)) return(invisible(NULL))

  set_if <- function(fn, id, ...) {
    if (!is.null(ui[[id]])) fn(session, id, ...)
  }

  set_if(shiny::updateSelectInput, "fs_model_choice", selected = ui$fs_model_choice)
  set_if(shiny::updateSliderInput, "fs_horizon_months", value = ui$fs_horizon_months)
  set_if(shiny::updateSliderInput, "fs_test_months", value = ui$fs_test_months)

  set_if(shiny::updateSliderInput, "fs_cp", value = ui$fs_cp)
  set_if(shiny::updateSliderInput, "fs_season", value = ui$fs_season)
  set_if(shiny::updateSliderInput, "fs_holiday_prior", value = ui$fs_holiday_prior)
  set_if(shiny::updateCheckboxInput, "fs_yearly", value = ui$fs_yearly)
  set_if(shiny::updateCheckboxInput, "fs_weekly", value = ui$fs_weekly)
  set_if(shiny::updateCheckboxInput, "fs_daily", value = ui$fs_daily)
  set_if(shiny::updateCheckboxInput, "fs_exclude_sundays", value = ui$fs_exclude_sundays)

  set_if(shiny::updateRadioButtons, "fs_arima_mode", selected = ui$fs_arima_mode)
  set_if(shiny::updateNumericInput, "fs_p", value = ui$fs_p)
  set_if(shiny::updateNumericInput, "fs_d", value = ui$fs_d)
  set_if(shiny::updateNumericInput, "fs_q", value = ui$fs_q)
  set_if(shiny::updateNumericInput, "fs_P", value = ui$fs_P)
  set_if(shiny::updateNumericInput, "fs_D", value = ui$fs_D)
  set_if(shiny::updateNumericInput, "fs_Q", value = ui$fs_Q)

  set_if(shiny::updateCheckboxInput, "fs_show_trend", value = ui$fs_show_trend)
  set_if(shiny::updateCheckboxInput, "fs_show_uncertainty", value = ui$fs_show_uncertainty)
  set_if(shiny::updateCheckboxInput, "fs_show_holidays", value = ui$fs_show_holidays)
  set_if(shiny::updateCheckboxInput, "fs_show_changepoints", value = ui$fs_show_changepoints)
  set_if(colourpicker::updateColourInput, "fs_color_actual", value = ui$fs_color_actual)
  set_if(colourpicker::updateColourInput, "fs_color_forecast", value = ui$fs_color_forecast)
  set_if(colourpicker::updateColourInput, "fs_color_trend", value = ui$fs_color_trend)
  set_if(colourpicker::updateColourInput, "fs_color_ci", value = ui$fs_color_ci)

  set_if(shiny::updateCheckboxGroupInput, "fs_compare_choices", selected = ui$fs_compare_choices)
  set_if(shiny::updateNumericInput, "fs_cv_folds", value = ui$fs_cv_folds)
  set_if(shiny::updateSliderInput, "fs_holiday_years", value = ui$fs_holiday_years)
  set_if(shiny::updateCheckboxInput, "fs_use_holidays", value = ui$fs_use_holidays)

  set_if(shiny::updateNumericInput, "fs_lstm_epochs", value = ui$fs_lstm_epochs)
  set_if(shiny::updateNumericInput, "fs_lstm_hidden", value = ui$fs_lstm_hidden)
  set_if(shiny::updateNumericInput, "fs_lstm_lookback", value = ui$fs_lstm_lookback)
  set_if(shiny::updateNumericInput, "fs_lstm_lr", value = ui$fs_lstm_lr)

  invisible(NULL)
}
