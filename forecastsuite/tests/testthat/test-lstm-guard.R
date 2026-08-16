test_that("lstm_available() reflects whether torch is installed", {
  expect_equal(lstm_available(), requireNamespace("torch", quietly = TRUE))
})

test_that("lstm fit fails with a clear, actionable message when torch is missing", {
  skip_if(requireNamespace("torch", quietly = TRUE), "torch is installed in this environment")
  m <- get_model("lstm")
  expect_error(
    m$fit(data.frame(ds = Sys.Date() - 30:1, y = rnorm(30))),
    "torch"
  )
})

test_that("library(forecastsuite) never errors even without torch", {
  # Loading the package must not fail just because an optional Suggests
  # dependency is absent -- only *calling* the lstm fit function should.
  expect_true(exists("get_model"))
  expect_no_error(get_model("lstm"))
})
