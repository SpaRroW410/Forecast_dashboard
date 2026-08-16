test_that("built-in models are registered with the right contract", {
  models <- list_models(available_only = FALSE)
  keys <- vapply(models, function(m) m$key, "")
  expect_true(all(c("prophet", "arima", "sarima", "ets", "tbats", "nnetar", "holtwinters", "lstm") %in% keys))

  for (m in models) {
    expect_true(is.function(m$fit))
    expect_true(is.function(m$forecast))
    expect_true(is.function(m$to_tibble))
  }
})

test_that("get_model errors clearly on an unknown key", {
  expect_error(get_model("not_a_real_model"), "Unknown model")
})

test_that("list_models(available_only = TRUE) omits lstm without torch installed", {
  skip_if(requireNamespace("torch", quietly = TRUE), "torch is installed in this environment")
  keys <- vapply(list_models(available_only = TRUE), function(m) m$key, "")
  expect_false("lstm" %in% keys)
})

test_that("only prophet supports holidays among the built-ins", {
  models <- list_models(available_only = FALSE)
  holiday_keys <- vapply(models, function(m) if (isTRUE(m$supports_holidays)) m$key else NA_character_, "")
  holiday_keys <- holiday_keys[!is.na(holiday_keys)]
  expect_equal(holiday_keys, "prophet")
})
