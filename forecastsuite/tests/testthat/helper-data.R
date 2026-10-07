make_synthetic_series <- function(n = 300, seed = 42) {
  set.seed(seed)
  tibble::tibble(
    ds = seq.Date(as.Date("2022-01-01"), by = "day", length.out = n),
    y  = 100 + (1:n) * 0.03 + 10 * sin(2 * pi * (1:n) / 7) + stats::rnorm(n, 0, 3)
  )
}

# Stand-in for the user's workspace in app tests: the app reads "environment"
# imports from the `data_env` it is given (run_app() passes the caller's
# environment), so tests hand it this private environment instead of writing
# to the global environment.
fs_test_env <- new.env(parent = emptyenv())
