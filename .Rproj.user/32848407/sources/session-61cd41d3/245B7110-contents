compute_forecast_metrics <- function(actual_df, forecast_df, label = "Test") {
  joined <- inner_join(forecast_df, actual_df, by = "ds")
  
  if (nrow(joined) < 2) {
    return(tibble::tibble(Set = label, Metric = c("MASE", "sMAPE (%)", "RMSE"), Value = NA))
  }
  
  mae_naive <- mean(abs(diff(actual_df$y)), na.rm = TRUE)
  mae_model <- mean(abs(joined$y - joined$yhat), na.rm = TRUE)
  mase <- mae_model / mae_naive
  
  smape <- mean(2 * abs(joined$y - joined$yhat) /
                  (abs(joined$y) + abs(joined$yhat)), na.rm = TRUE) * 100
  
  rmse <- sqrt(mean((joined$y - joined$yhat)^2, na.rm = TRUE))
  
  tibble::tibble(
    Set = label,
    Metric = c("MASE", "sMAPE (%)", "RMSE"),
    Value = round(c(mase, smape, rmse), 3)
  )
}


safe_compute_metrics <- function(forecast_df, actual_df, label) {
  if (nrow(actual_df) < 2) {
    return(tibble::tibble(Set = label, Metric = c("MASE", "sMAPE (%)", "RMSE"), Value = NA))
  }
  compute_forecast_metrics(actual_df, forecast_df, label = label)
}