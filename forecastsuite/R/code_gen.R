# Generates a standalone, runnable R snippet mirroring exactly what a
# "Fit & Forecast" / "Compare Selected Models" click just executed --
# the esquisse-style "show the code" panel for the Model tab
# (app_ui.R/app_server.R). Data arguments (train_df/test_df/holidays_df)
# are referenced as bare variable names rather than deparsed inline, since
# deparsing a whole data.frame would be enormous and unreadable; every
# other argument is deparsed as a literal so it reflects the actual UI
# state at fit time.

.deparse_arg_lines <- function(args_list) {
  if (length(args_list) == 0) return(character(0))
  vapply(names(args_list), function(nm) {
    sprintf("%s = %s", nm, deparse(args_list[[nm]], width.cutoff = 500L))
  }, character(1))
}

build_fit_code <- function(model_key, date_agg, scalar_args = list(),
                            uses_holidays = FALSE, horizon) {
  arg_lines <- c(
    "train_df = train_df",
    sprintf("date_agg = %s", deparse(date_agg)),
    if (uses_holidays) "holidays_df = holidays_df",
    .deparse_arg_lines(scalar_args)
  )

  fit_call <- sprintf("fit_obj <- model$fit(\n  %s\n)", paste(arg_lines, collapse = ",\n  "))

  plot_lines <- if (identical(model_key, "prophet")) {
    "plot_forecast_generic(fc_raw, train_df = train_df, model_obj = fit_obj, show_trend = TRUE)"
  } else {
    c(
      "# model$annotate(fit_obj) returns e.g. \"ARIMA(2,1,1)\" for arima/sarima",
      "plot_forecast_generic(fc_tib, train_df = train_df, subtitle = model$annotate(fit_obj))"
    )
  }

  lines <- c(
    "library(forecastsuite)",
    "",
    "# train_df / test_df: your finalized dataset's train/test split (ds, y columns)",
    if (uses_holidays) "# holidays_df: holidays configured on the Holidays tab (NULL if none)",
    "",
    sprintf('model <- get_model("%s")', model_key),
    fit_call,
    sprintf("fc_raw  <- model$forecast(fit_obj, h = %s)", deparse(horizon)),
    "fc_tib  <- model$to_tibble(fc_raw, test_df)",
    "",
    "safe_compute_metrics(fc_tib, test_df, label = model$label)",
    "",
    plot_lines
  )

  paste(lines, collapse = "\n")
}

build_comparison_code <- function(model_keys, date_agg, horizon) {
  keys_literal <- paste(sprintf('"%s"', model_keys), collapse = ", ")

  lines <- c(
    "library(forecastsuite)",
    "",
    "# train_df / test_df: your finalized dataset's train/test split (ds, y columns)",
    "",
    sprintf("model_keys <- c(%s)", keys_literal),
    "",
    "results <- lapply(model_keys, function(key) {",
    "  model   <- get_model(key)",
    sprintf("  fit_obj <- model$fit(train_df, date_agg = %s)", deparse(date_agg)),
    sprintf("  fc_raw  <- model$forecast(fit_obj, h = %s)", deparse(horizon)),
    "  fc_tib  <- model$to_tibble(fc_raw, test_df)",
    "  safe_compute_metrics(fc_tib, test_df, label = model$label)",
    "})",
    "",
    "comparison <- dplyr::bind_rows(results)"
  )

  paste(lines, collapse = "\n")
}
