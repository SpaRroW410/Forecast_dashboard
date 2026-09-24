# SARIMA adapter -- seasonal counterpart of model_arima.R. Reuses the same
# .fit_arima_family()/.arima_annotate() helpers with seasonal = TRUE, using
# the series' calendar-informed frequency (ts_frequency_for()) as the
# seasonal period when orders are auto-selected.

.sarima_fit <- function(train_df, date_agg = "day", auto = TRUE, order = NULL, seasonal_order = NULL, ...) {
  .fit_arima_family(train_df, date_agg, auto = auto, order = order,
                     seasonal_order = seasonal_order, seasonal = TRUE)
}
.sarima_forecast <- function(model, h, ...) forecast::forecast(model, h = h)
