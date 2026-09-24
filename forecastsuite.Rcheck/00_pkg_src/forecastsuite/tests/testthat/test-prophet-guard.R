test_that("prophet_available() reflects whether prophet is installed", {
  expect_equal(prophet_available(), requireNamespace("prophet", quietly = TRUE))
})

test_that("prophet fit fails with a clear, actionable message when prophet is missing", {
  skip_if(requireNamespace("prophet", quietly = TRUE), "prophet is installed in this environment")
  m <- get_model("prophet")
  expect_error(
    m$fit(data.frame(ds = Sys.Date() - 30:1, y = rnorm(30))),
    "prophet"
  )
})

test_that("library(forecastsuite) never errors even without prophet", {
  # Loading the package must not fail just because an optional Suggests
  # dependency is absent -- only *calling* the prophet fit function should.
  expect_true(exists("get_model"))
  expect_no_error(get_model("prophet"))
})
