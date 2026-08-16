.tbats_fit <- function(train_df, date_agg = "day", ...) {
  forecast::tbats(.prep_train_ts(train_df, date_agg))
}
.tbats_forecast <- function(model, h, ...) forecast::forecast(model, h = h)
