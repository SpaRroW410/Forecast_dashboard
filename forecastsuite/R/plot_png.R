# Static PNG renderings of the same content as plot_generic.R's plotly
# figures, using only base graphics (grDevices/graphics, both always
# available) rather than a headless-browser screenshot tool like
# webshot2/orca -- those need a browser or a legacy PhantomJS binary
# installed locally, which is exactly the kind of unverified, heavy
# dependency that caused this package's Windows install saga (see
# README's "Relationship to the hosted app"). These two functions are the
# content behind the "Download Plot (PNG)" / "Download Combined Plot
# (PNG)" buttons in R/app_server.R.

render_forecast_png <- function(file, forecast_df, train_df = NULL, model_obj = NULL,
                                 subtitle = NULL, title = "Forecast",
                                 show_trend = TRUE, show_uncertainty = TRUE,
                                 show_holidays = FALSE, show_changepoints = FALSE,
                                 color_actual = "#1b9e77", color_forecast = "#d95f02",
                                 color_trend = "#7570b3", color_ci = "#1b9e77",
                                 width = 1200, height = 700) {
  forecast_df$ds <- as.Date(forecast_df$ds)
  if (!is.null(train_df)) train_df$ds <- as.Date(train_df$ds)

  has_ci <- show_uncertainty && all(c("yhat_lower", "yhat_upper") %in% names(forecast_df))
  x_all <- c(if (!is.null(train_df)) train_df$ds, forecast_df$ds)
  y_all <- c(if (!is.null(train_df)) train_df$y, forecast_df$yhat,
             if (has_ci) forecast_df$yhat_lower, if (has_ci) forecast_df$yhat_upper)
  y_all <- y_all[is.finite(y_all)]

  grDevices::png(file, width = width, height = height, res = 120)
  on.exit(grDevices::dev.off(), add = TRUE)

  main_title <- if (!is.null(subtitle) && nzchar(subtitle)) paste0(title, "\n", subtitle) else title
  graphics::plot(range(x_all), range(y_all), type = "n",
                 xlab = "Date", ylab = "Value", main = main_title)

  if (has_ci) {
    ok <- is.finite(forecast_df$yhat_lower) & is.finite(forecast_df$yhat_upper)
    if (any(ok)) {
      graphics::polygon(c(forecast_df$ds[ok], rev(forecast_df$ds[ok])),
                         c(forecast_df$yhat_lower[ok], rev(forecast_df$yhat_upper[ok])),
                         col = grDevices::adjustcolor(color_ci, alpha.f = 0.2), border = NA)
    }
  }

  if (show_holidays && "holidays" %in% names(forecast_df)) {
    holiday_dates <- unique(forecast_df$ds[!is.na(forecast_df$holidays)])
    for (d in holiday_dates) {
      graphics::abline(v = d, col = grDevices::adjustcolor(color_forecast, alpha.f = 0.3), lty = 2)
    }
  }
  if (show_changepoints && !is.null(model_obj) && "changepoints" %in% names(model_obj)) {
    for (d in as.Date(model_obj$changepoints)) {
      graphics::abline(v = d, col = grDevices::adjustcolor(color_trend, alpha.f = 0.3), lty = 3)
    }
  }

  if (!is.null(train_df) && all(c("ds", "y") %in% names(train_df))) {
    graphics::lines(train_df$ds, train_df$y, col = color_actual, lwd = 1.5)
  }
  graphics::lines(forecast_df$ds, forecast_df$yhat, col = color_forecast, lwd = 1.5)

  legend_labels <- character(0); legend_colors <- character(0); legend_lty <- numeric(0)
  if (!is.null(train_df)) { legend_labels <- c(legend_labels, "Actual"); legend_colors <- c(legend_colors, color_actual); legend_lty <- c(legend_lty, 1) }
  legend_labels <- c(legend_labels, "Forecast"); legend_colors <- c(legend_colors, color_forecast); legend_lty <- c(legend_lty, 1)

  if (show_trend && "trend" %in% names(forecast_df)) {
    graphics::lines(forecast_df$ds, forecast_df$trend, col = color_trend, lwd = 1.2, lty = 3)
    legend_labels <- c(legend_labels, "Trend"); legend_colors <- c(legend_colors, color_trend); legend_lty <- c(legend_lty, 3)
  }

  graphics::legend("topleft", legend = legend_labels, col = legend_colors, lty = legend_lty, bty = "n", cex = 0.8)
  invisible(file)
}

# forecasts: named list of ds/yhat tibbles, as produced for plot_model_comparison().
render_comparison_png <- function(file, forecasts, train_df = NULL,
                                   title = "Model Comparison", width = 1200, height = 700) {
  forecasts <- forecasts[!vapply(forecasts, is.null, logical(1))]
  if (!length(forecasts)) stop("No forecasts to plot.", call. = FALSE)
  forecasts <- lapply(forecasts, function(fc) { fc$ds <- as.Date(fc$ds); fc })
  if (!is.null(train_df)) train_df$ds <- as.Date(train_df$ds)

  palette <- c("#1b9e77", "#d95f02", "#7570b3", "#e7298a",
                "#66a61e", "#e6ab02", "#a6761d", "#666666")

  # do.call(c, ...) rather than unlist() -- unlist() strips the Date class
  # off each element, which would leave the x-axis showing raw day-counts
  # instead of formatted dates even though the later lines() calls still
  # get real Date vectors (plot()'s initial call is what fixes axis type).
  ds_list <- lapply(forecasts, `[[`, "ds")
  x_all <- c(if (!is.null(train_df)) train_df$ds, do.call(c, ds_list))
  y_all <- c(if (!is.null(train_df)) train_df$y, unlist(lapply(forecasts, `[[`, "yhat")))
  y_all <- y_all[is.finite(y_all)]

  grDevices::png(file, width = width, height = height, res = 120)
  on.exit(grDevices::dev.off(), add = TRUE)

  graphics::plot(range(x_all), range(y_all), type = "n", xlab = "Date", ylab = "Value", main = title)

  legend_labels <- character(0); legend_colors <- character(0)
  if (!is.null(train_df) && all(c("ds", "y") %in% names(train_df))) {
    graphics::lines(train_df$ds, train_df$y, col = "#333333", lwd = 1.5)
    legend_labels <- c(legend_labels, "Actual"); legend_colors <- c(legend_colors, "#333333")
  }

  for (i in seq_along(forecasts)) {
    fc <- forecasts[[i]]
    if (!all(c("ds", "yhat") %in% names(fc))) next
    col <- palette[((i - 1) %% length(palette)) + 1]
    graphics::lines(fc$ds, fc$yhat, col = col, lwd = 2)
    legend_labels <- c(legend_labels, names(forecasts)[i]); legend_colors <- c(legend_colors, col)
  }

  graphics::legend("topleft", legend = legend_labels, col = legend_colors, lty = 1, lwd = 2, bty = "n", cex = 0.8)
  invisible(file)
}

# Base-graphics twin of plot_group_overlay(): each group's actual (solid)
# and forecast (dashed) share one palette color.
render_group_overlay_png <- function(file, forecasts, actuals = list(),
                                      title = "Forecast by Group", width = 1200, height = 700) {
  forecasts <- forecasts[!vapply(forecasts, is.null, logical(1))]
  if (!length(forecasts)) stop("No forecasts to plot.", call. = FALSE)
  forecasts <- lapply(forecasts, function(fc) { fc$ds <- as.Date(fc$ds); fc })
  actuals <- lapply(actuals, function(a) { if (!is.null(a)) a$ds <- as.Date(a$ds); a })

  palette <- c("#1b9e77", "#d95f02", "#7570b3", "#e7298a",
                "#66a61e", "#e6ab02", "#a6761d", "#666666")
  groups <- names(forecasts)

  # See render_comparison_png()'s comment: do.call(c, ...) preserves the
  # Date class across list elements, unlist() does not.
  x_all <- c(do.call(c, lapply(actuals, `[[`, "ds")), do.call(c, lapply(forecasts, `[[`, "ds")))
  y_all <- c(unlist(lapply(actuals, `[[`, "y")), unlist(lapply(forecasts, `[[`, "yhat")))
  y_all <- y_all[is.finite(y_all)]

  grDevices::png(file, width = width, height = height, res = 120)
  on.exit(grDevices::dev.off(), add = TRUE)

  graphics::plot(range(x_all), range(y_all), type = "n", xlab = "Date", ylab = "Value", main = title)

  legend_labels <- character(0); legend_colors <- character(0); legend_lty <- numeric(0)
  for (i in seq_along(groups)) {
    g <- groups[i]
    col <- palette[((i - 1) %% length(palette)) + 1]

    actual <- actuals[[g]]
    if (!is.null(actual) && all(c("ds", "y") %in% names(actual))) {
      graphics::lines(actual$ds, actual$y, col = col, lwd = 1.5)
    }
    fc <- forecasts[[g]]
    if (all(c("ds", "yhat") %in% names(fc))) {
      graphics::lines(fc$ds, fc$yhat, col = col, lwd = 2, lty = 2)
    }
    legend_labels <- c(legend_labels, g); legend_colors <- c(legend_colors, col); legend_lty <- c(legend_lty, 1)
  }

  graphics::legend("topleft", legend = legend_labels, col = legend_colors, lty = legend_lty, lwd = 2, bty = "n", cex = 0.8)
  invisible(file)
}
