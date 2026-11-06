# Regression tests for the Prophet horizon/frequency bug: with weekly
# seasonality on (the default), the future dataframe used to step by WEEK
# while the horizon was counted in the data's own periods, so a 24-month
# daily request ran ~14 years ahead.

skip_if_not_installed("prophet")

future_rows <- function(fc, train) {
  fc <- as.data.frame(fc)
  fc[as.Date(fc$ds) > as.Date(max(train$ds)), , drop = FALSE]
}

test_that("daily data forecasts in daily steps for the requested horizon (weekly seasonality on)", {
  train <- demo_series()
  train <- train[as.Date(train$ds) <= as.Date("1959-09-30"), ]
  h <- convert_months_to_horizon(3, "day")
  res <- quiet(prepare_forecast(train, NULL, 0.05, 10, 5, h,
                                exclude_sundays = FALSE, yearly = FALSE, weekly = TRUE, daily = FALSE,
                                freq = seq_unit_for("day")))
  fut <- future_rows(res$forecast, train)
  expect_equal(nrow(fut), h)
  expect_true(all(diff(as.Date(fut$ds)) == 1))
  expect_lte(as.numeric(max(as.Date(fut$ds)) - as.Date(max(train$ds))), 95)
})

test_that("weekly data forecasts in weekly steps", {
  daily <- demo_series()
  weekly <- daily |>
    mutate(ds = floor_date(ds, "week")) |>
    group_by(ds) |> summarise(y = sum(y), .groups = "drop")
  h <- convert_months_to_horizon(6, "week")
  res <- quiet(prepare_forecast(weekly, NULL, 0.05, 10, 5, h,
                                exclude_sundays = FALSE, yearly = FALSE, weekly = FALSE, daily = FALSE,
                                freq = seq_unit_for("week")))
  fut <- future_rows(res$forecast, weekly)
  expect_equal(nrow(fut), h)
  expect_true(all(diff(as.Date(fut$ds)) == 7))
})

test_that("monthly data forecasts in monthly steps", {
  daily <- demo_series()
  monthly <- daily |>
    mutate(ds = floor_date(ds, "month")) |>
    group_by(ds) |> summarise(y = sum(y), .groups = "drop")
  h <- convert_months_to_horizon(6, "month")
  res <- quiet(prepare_forecast(monthly, NULL, 0.05, 10, 5, h,
                                exclude_sundays = FALSE, yearly = FALSE, weekly = TRUE, daily = FALSE,
                                freq = seq_unit_for("month")))
  fut <- future_rows(res$forecast, monthly)
  expect_equal(nrow(fut), h)
  expect_true(all(format(as.Date(fut$ds), "%d") == "01"))
  expect_equal(format(max(as.Date(fut$ds)), "%Y-%m"), "1960-06")
})

test_that("a finalized holiday list with windows is accepted by Prophet", {
  train <- demo_series()
  train <- train[as.Date(train$ds) <= as.Date("1959-09-30"), ]
  hol <- expand_fixed_holidays(c("01-26", "08-15"), 1958:1960,
                               list("01-26" = "Republic Day", "08-15" = "Independence Day"))
  final <- apply_window_settings(hol, tibble(holiday = "Independence Day", lower_window = -1L, upper_window = 1L))
  res <- quiet(prepare_forecast(train, final, 0.05, 10, 5, 30,
                                exclude_sundays = TRUE, yearly = FALSE, weekly = TRUE, daily = FALSE,
                                freq = "day"))
  expect_true("holidays" %in% names(res$forecast))
  expect_equal(nrow(future_rows(res$forecast, train)), 30)
})
