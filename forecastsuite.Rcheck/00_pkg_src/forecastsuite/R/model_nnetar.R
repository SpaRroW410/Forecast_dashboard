.nnetar_fit <- function(train_df, date_agg = "day", ...) {
  forecast::nnetar(.prep_train_ts(train_df, date_agg))
}
# forecast.nnetar() doesn't compute prediction intervals unless PI = TRUE
# is passed (they require bootstrap simulation and are comparatively
# expensive) -- left off by default for responsiveness, so .to_tibble()
# simply has no yhat_lower/yhat_upper for this model, which
# plot_forecast_generic() already handles gracefully.
.nnetar_forecast <- function(model, h, ...) forecast::forecast(model, h = h)
