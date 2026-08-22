# Model-agnostic plotly plotting. Works off just ds/yhat(+intervals) for
# models that only produce that (ARIMA/SARIMA/ETS/TBATS/NNETAR/Holt-
# Winters/LSTM), and additionally draws Prophet's richer trend/holiday/
# changepoint decomposition when the raw forecast object still has those
# columns (i.e. pass the adapter's raw `forecast()` output here for
# plotting, and the standardized to_tibble() output to the metrics
# functions instead).
#
# `subtitle` is used by the ARIMA/SARIMA adapters' `annotate()` output
# (e.g. "ARIMA(2,1,1)(1,0,0)[12]") so the fitted order is visible on the
# plot, not just implicit in the model object.

# colourInput() (and any user-supplied color) comes back as a plain hex
# string with no alpha; the uncertainty ribbon needs to stay translucent
# regardless of which color is picked, so convert to rgba() here rather
# than asking the UI for a separate opacity control.
.fs_hex_to_rgba <- function(hex, alpha = 0.2) {
  rgb <- tryCatch(grDevices::col2rgb(hex), error = function(e) grDevices::col2rgb("#1b9e77"))
  sprintf("rgba(%d,%d,%d,%s)", rgb[1], rgb[2], rgb[3], alpha)
}

# Shared by plot_model_comparison() (one dataset, many models) and
# plot_group_overlay() (one model, many groups) so both read consistently.
.fs_group_palette <- c("#1b9e77", "#d95f02", "#7570b3", "#e7298a",
                         "#66a61e", "#e6ab02", "#a6761d", "#666666")

plot_forecast_generic <- function(forecast_df, train_df = NULL, model_obj = NULL,
                                   subtitle = NULL, title = "Forecast",
                                   show_trend = TRUE, show_uncertainty = TRUE,
                                   show_holidays = FALSE, show_changepoints = FALSE,
                                   max_marker_lines = 60,
                                   color_actual = "#1b9e77", color_forecast = "#d95f02",
                                   color_trend = "#7570b3", color_ci = "#1b9e77") {
  p <- plotly::plot_ly()

  if (show_uncertainty && all(c("yhat_lower", "yhat_upper") %in% names(forecast_df))) {
    p <- p |> plotly::add_ribbons(
      data = forecast_df, x = ~ds, ymin = ~yhat_lower, ymax = ~yhat_upper,
      name = "Uncertainty", fillcolor = .fs_hex_to_rgba(color_ci, 0.2), line = list(width = 0)
    )
  }

  if (!is.null(train_df) && all(c("ds", "y") %in% names(train_df))) {
    p <- p |> plotly::add_lines(
      data = train_df, x = ~ds, y = ~y, name = "Actual",
      line = list(color = color_actual)
    )
  }

  p <- p |> plotly::add_lines(
    data = forecast_df, x = ~ds, y = ~yhat, name = "Forecast",
    line = list(color = color_forecast)
  )

  if (show_trend && "trend" %in% names(forecast_df)) {
    p <- p |> plotly::add_lines(
      data = forecast_df, x = ~ds, y = ~trend, name = "Trend",
      line = list(color = color_trend, dash = "dot")
    )
  }

  # Cap marker-line counts for the same reason the hosted app's static plot
  # does (helpers/plot_utils.R): long horizons with recurring holidays can
  # otherwise render as an unreadable wall of overlapping lines.
  shapes <- list()

  if (show_holidays && "holidays" %in% names(forecast_df)) {
    holiday_dates <- unique(forecast_df$ds[!is.na(forecast_df$holidays)])
    if (length(holiday_dates) > max_marker_lines) {
      idx <- round(seq(1, length(holiday_dates), length.out = max_marker_lines))
      holiday_dates <- holiday_dates[idx]
    }
    shapes <- c(shapes, lapply(holiday_dates, function(d) {
      list(type = "line", x0 = d, x1 = d, y0 = 0, y1 = 1, yref = "paper",
           line = list(color = "#d95f02", dash = "dash", width = 1), opacity = 0.4)
    }))
  }

  if (show_changepoints && !is.null(model_obj) && "changepoints" %in% names(model_obj)) {
    cps <- model_obj$changepoints
    if (length(cps) > max_marker_lines) {
      idx <- round(seq(1, length(cps), length.out = max_marker_lines))
      cps <- cps[idx]
    }
    shapes <- c(shapes, lapply(cps, function(d) {
      list(type = "line", x0 = d, x1 = d, y0 = 0, y1 = 1, yref = "paper",
           line = list(color = "#7570b3", dash = "dot", width = 1), opacity = 0.4)
    }))
  }

  full_title <- if (!is.null(subtitle) && nzchar(subtitle)) {
    paste0(title, "<br><sup>", subtitle, "</sup>")
  } else {
    title
  }

  p |> plotly::layout(
    title = full_title,
    xaxis = list(title = "Date"),
    yaxis = list(title = "Value"),
    shapes = shapes,
    hovermode = "x unified"
  )
}

# Overlays several models' forecasts on one plot for the "Compare Selected
# Models" flow, which previously produced only a metrics table. Generalizes
# the hosted app's 4-prior "Combined Trend Comparison" (server_forecast.R)
# to any number of registered models.
#
# forecasts: named list of ds/yhat tibbles, names used as the legend labels.
plot_model_comparison <- function(forecasts, train_df = NULL,
                                   title = "Model Comparison") {
  forecasts <- forecasts[!vapply(forecasts, is.null, logical(1))]
  if (!length(forecasts)) stop("No forecasts to plot.", call. = FALSE)

  p <- plotly::plot_ly()

  if (!is.null(train_df) && all(c("ds", "y") %in% names(train_df))) {
    p <- p |> plotly::add_lines(
      data = train_df, x = ~ds, y = ~y, name = "Actual",
      line = list(color = "#333333", width = 1.5)
    )
  }

  for (i in seq_along(forecasts)) {
    fc <- forecasts[[i]]
    if (!all(c("ds", "yhat") %in% names(fc))) next
    p <- p |> plotly::add_lines(
      x = fc$ds, y = fc$yhat,
      name = names(forecasts)[i],
      line = list(color = .fs_group_palette[((i - 1) %% length(.fs_group_palette)) + 1], width = 2)
    )
  }

  p |> plotly::layout(
    title = title,
    xaxis = list(title = "Date"),
    yaxis = list(title = "Value"),
    hovermode = "x unified",
    legend = list(orientation = "h", y = -0.2)
  )
}

# One model, many groups: each group's ACTUAL history (solid) and FORECAST
# (dashed) share one palette color, so N groups reads as N colors instead
# of 2N with no visual grouping. Unlike plot_model_comparison() (forecasts
# only -- there's no single "Actual" line that's correct for every model),
# every group genuinely has its own actual series, so both are drawn here.
#
# forecasts, actuals: named lists keyed by group (same names); a group
# missing from `actuals` still gets its forecast line drawn.
plot_group_overlay <- function(forecasts, actuals = list(), title = "Forecast by Group") {
  forecasts <- forecasts[!vapply(forecasts, is.null, logical(1))]
  if (!length(forecasts)) stop("No forecasts to plot.", call. = FALSE)

  p <- plotly::plot_ly()
  groups <- names(forecasts)

  for (i in seq_along(groups)) {
    g <- groups[i]
    color <- .fs_group_palette[((i - 1) %% length(.fs_group_palette)) + 1]

    actual <- actuals[[g]]
    if (!is.null(actual) && all(c("ds", "y") %in% names(actual))) {
      p <- p |> plotly::add_lines(
        x = actual$ds, y = actual$y,
        name = paste0(g, " (actual)"), legendgroup = g,
        line = list(color = color, width = 1.5)
      )
    }

    fc <- forecasts[[g]]
    if (all(c("ds", "yhat") %in% names(fc))) {
      p <- p |> plotly::add_lines(
        x = fc$ds, y = fc$yhat,
        name = paste0(g, " (forecast)"), legendgroup = g,
        line = list(color = color, width = 2, dash = "dash")
      )
    }
  }

  p |> plotly::layout(
    title = title,
    xaxis = list(title = "Date"),
    yaxis = list(title = "Value"),
    hovermode = "x unified",
    legend = list(orientation = "h", y = -0.2)
  )
}
