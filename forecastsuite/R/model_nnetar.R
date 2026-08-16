.nnetar_fit <- function(train_df, date_agg = "day", ...) {
  forecast::nnetar(.prep_train_ts(train_df, date_agg))
}
.nnetar_forecast <- function(model, h, ...) forecast::forecast(model, h = h)
