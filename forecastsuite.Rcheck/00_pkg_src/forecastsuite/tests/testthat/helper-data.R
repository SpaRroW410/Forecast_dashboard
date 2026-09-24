make_synthetic_series <- function(n = 300, seed = 42) {
  set.seed(seed)
  tibble::tibble(
    ds = seq.Date(as.Date("2022-01-01"), by = "day", length.out = n),
    y  = 100 + (1:n) * 0.03 + 10 * sin(2 * pi * (1:n) / 7) + stats::rnorm(n, 0, 3)
  )
}
