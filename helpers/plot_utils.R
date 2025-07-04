plot_forecast <- function(model, forecast,
                          show_trend = TRUE,
                          show_uncertainty = TRUE,
                          show_holidays = FALSE,
                          show_changepoints = FALSE,
                          trend_color = "#1b9e77",
                          uncertainty_color = "#1b9e77",
                          holiday_color = "#d95f02",
                          changepoint_color = "#7570b3",
                          font_family = "serif") {

  p <- plot(model, forecast) +
    ggtitle("Forecasted Incidence with Prophet") +
    theme_minimal(base_family = font_family) +
    theme(
      plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
      axis.title = element_text(size = 11)
    )

  if (show_uncertainty && all(c("yhat_lower", "yhat_upper") %in% names(forecast))) {
    p <- p + geom_ribbon(aes(ymin = yhat_lower, ymax = yhat_upper),
                         data = forecast, fill = uncertainty_color, alpha = 0.2)
  }

  if (show_trend && "trend" %in% names(forecast)) {
    p <- p + geom_line(aes(y = trend), data = forecast, color = trend_color, linewidth = 1.2)
  }

  if (show_holidays && "holidays" %in% names(forecast)) {
    holiday_dates <- unique(forecast$ds[!is.na(forecast$holidays)])
    p <- p + geom_vline(xintercept = as.numeric(holiday_dates),
                        linetype = "dashed", color = holiday_color, alpha = 0.6)
  }

  if (show_changepoints && "changepoints" %in% names(model)) {
    p <- p + geom_vline(xintercept = as.numeric(model$changepoints),
                        linetype = "dotted", color = changepoint_color, alpha = 0.5)
  }

  return(p)
}