.ets_fit <- function(train_df, date_agg = "day", ...) {
  forecast::ets(.prep_train_ts(train_df, date_agg))
}
.ets_forecast <- function(model, h, ...) forecast::forecast(model, h = h)
