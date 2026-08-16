# ARIMA adapter — supports both auto-selected orders (forecast::auto.arima)
# and manually entered (p,d,q) orders (forecast::Arima). Non-seasonal by
# design; see model_sarima.R for the seasonal counterpart.

.fit_arima_family <- function(train_df, date_agg = "day", auto = TRUE,
                               order = NULL, seasonal_order = NULL,
                               seasonal = FALSE, ...) {
  ts_train <- .prep_train_ts(train_df, date_agg)

  if (isTRUE(auto)) {
    forecast::auto.arima(ts_train, seasonal = seasonal)
  } else {
    if (is.null(order) || length(order) != 3) {
      stop("Manual ARIMA fitting requires `order = c(p, d, q)`.", call. = FALSE)
    }
    seas <- if (seasonal && !is.null(seasonal_order) && length(seasonal_order) == 3) {
      list(order = seasonal_order, period = stats::frequency(ts_train))
    } else {
      list(order = c(0, 0, 0))
    }
    forecast::Arima(ts_train, order = order, seasonal = seas)
  }
}

# Standard-notation order string, e.g. "ARIMA(2,1,1)(1,0,0)[12]", used to
# annotate plots so the fitted p,d,q/P,D,Q is visible, not just implicit.
.arima_annotate <- function(model_obj) {
  ord <- tryCatch(forecast::arimaorder(model_obj), error = function(e) NULL)
  if (is.null(ord)) return("")
  nm <- names(ord)
  p <- ord[["p"]]; d <- ord[["d"]]; q <- ord[["q"]]
  has_seasonal <- all(c("P", "D", "Q") %in% nm) &&
    (ord[["P"]] > 0 || ord[["D"]] > 0 || ord[["Q"]] > 0)
  if (has_seasonal) {
    freq <- if ("Frequency" %in% nm) ord[["Frequency"]] else 1
    sprintf("ARIMA(%d,%d,%d)(%d,%d,%d)[%d]", p, d, q, ord[["P"]], ord[["D"]], ord[["Q"]], freq)
  } else {
    sprintf("ARIMA(%d,%d,%d)", p, d, q)
  }
}

.arima_fit <- function(train_df, date_agg = "day", auto = TRUE, order = NULL, seasonal_order = NULL, ...) {
  .fit_arima_family(train_df, date_agg, auto = auto, order = order,
                     seasonal_order = seasonal_order, seasonal = FALSE)
}
.arima_forecast <- function(model, h, ...) forecast::forecast(model, h = h)

# Registration itself happens in zzz_register_builtins.R, which loads last
# (alphabetically, by convention) so registry.R and every model_*.R file's
# definitions are guaranteed to already exist.
