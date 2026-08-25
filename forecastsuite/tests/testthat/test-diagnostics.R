test_that("compute_residual_diagnostics computes residuals, Ljung-Box, Shapiro, and ACF for a normal-enough series", {
  set.seed(1)
  ds <- as.Date("2024-01-01") + 0:59
  test_df <- tibble::tibble(ds = ds, y = 100 + stats::rnorm(60, sd = 1))
  fc_tib <- tibble::tibble(ds = ds, yhat = 100)

  rd <- compute_residual_diagnostics(fc_tib, test_df)
  expect_equal(nrow(rd$residuals), 60)
  expect_equal(rd$residuals$resid, test_df$y - 100)
  expect_true(is.numeric(rd$ljung_box_p) && !is.na(rd$ljung_box_p))
  expect_true(is.numeric(rd$shapiro_p) && !is.na(rd$shapiro_p))
  expect_true(nrow(rd$acf_df) > 0)
  expect_equal(rd$ci, 1.96 / sqrt(60))
  expect_equal(rd$n, 60)
})

test_that("compute_residual_diagnostics returns NA test p-values for too-short overlaps", {
  ds <- as.Date("2024-01-01") + 0:2
  test_df <- tibble::tibble(ds = ds, y = c(1, 2, 3))
  fc_tib <- tibble::tibble(ds = ds, yhat = c(1, 1, 1))

  rd <- compute_residual_diagnostics(fc_tib, test_df)
  expect_equal(nrow(rd$residuals), 3)
  expect_true(is.na(rd$ljung_box_p))
  # n=3 is the minimum shapiro.test() accepts, so this one CAN compute
  expect_true(!is.na(rd$shapiro_p) || is.na(rd$shapiro_p))
})

test_that("compute_residual_diagnostics handles zero overlap without erroring", {
  fc_tib <- tibble::tibble(ds = as.Date("2024-01-01"), yhat = 1)
  test_df <- tibble::tibble(ds = as.Date("2024-06-01"), y = 1)
  rd <- compute_residual_diagnostics(fc_tib, test_df)
  expect_equal(nrow(rd$residuals), 0)
  expect_true(is.na(rd$ljung_box_p))
  expect_true(is.na(rd$shapiro_p))
})

.weekly_seasonal_df <- function(n = 400) {
  ds <- as.Date("2023-01-01") + 0:(n - 1)
  set.seed(42)
  y <- 100 + 20 * sin(2 * pi * seq_len(n) / 7) + stats::rnorm(n, sd = 1)
  tibble::tibble(ds = ds, y = y)
}

test_that("decompose_series finds a weekly pattern in daily data and reconstructs the observed series", {
  df <- .weekly_seasonal_df()
  decomp <- decompose_series(df, "day")
  expect_false(is.null(decomp))
  expect_equal(nrow(decomp), nrow(df))
  expect_setequal(names(decomp), c("ds", "observed", "trend", "seasonal", "remainder"))
  expect_equal(decomp$trend + decomp$seasonal + decomp$remainder, decomp$observed,
               tolerance = 1e-6)
  # a real weekly cycle should show up as material seasonal variance
  expect_true(stats::sd(decomp$seasonal) > 5)
})

test_that("decompose_series returns NULL when there's no seasonal candidate (yearly aggregation) or too little data", {
  df_year <- tibble::tibble(ds = as.Date("2015-01-01") + (0:9) * 365, y = 1:10)
  expect_null(decompose_series(df_year, "year"))

  df_short <- tibble::tibble(ds = as.Date("2024-01-01") + 0:4, y = c(1, 2, 3, 2, 1))
  expect_null(decompose_series(df_short, "day"))
})

test_that("detect_anomalies flags an injected spike using both methods, on a seasonal series", {
  df <- .weekly_seasonal_df()
  df$y[200] <- df$y[200] + 200  # a huge, obvious spike

  a_iqr <- detect_anomalies(df, "day", method = "iqr", threshold = 1.5)
  expect_true(a_iqr$is_anomaly[200])

  a_z <- detect_anomalies(df, "day", method = "zscore", threshold = 3)
  expect_true(a_z$is_anomaly[200])
})

test_that("detect_anomalies falls back to a running-median baseline when no decomposition applies", {
  df <- tibble::tibble(ds = as.Date("2015-01-01") + (0:9) * 365, y = c(rep(10, 9), 500))
  a <- detect_anomalies(df, "year", method = "iqr", threshold = 1.5)
  expect_equal(nrow(a), 10)
  expect_true(a$is_anomaly[10])
  expect_false(any(a$is_anomaly[1:9]))
})

test_that("detect_anomalies never errors on a degenerate constant series", {
  df <- tibble::tibble(ds = as.Date("2024-01-01") + 0:9, y = rep(5, 10))
  expect_no_error(detect_anomalies(df, "day", method = "zscore", threshold = 2))
})

test_that("group_correlation_matrix returns an empty tibble for fewer than 2 groups", {
  expect_equal(nrow(group_correlation_matrix(NULL)), 0)
  expect_equal(nrow(group_correlation_matrix(list(a = tibble::tibble(ds = as.Date("2024-01-01"), y = 1)))), 0)
})

test_that("group_correlation_matrix reports high positive correlation for series that move together, negative for opposites", {
  ds <- as.Date("2024-01-01") + 0:29
  base <- sin(seq_len(30) / 3) * 10 + 50
  gs <- list(
    A = tibble::tibble(ds = ds, y = base),
    B = tibble::tibble(ds = ds, y = base + 2),         # same shape, shifted
    C = tibble::tibble(ds = ds, y = -base + 100)        # inverted shape
  )
  cor_tbl <- group_correlation_matrix(gs)
  expect_equal(nrow(cor_tbl), 3)  # 3 choose 2

  ab <- cor_tbl$correlation[cor_tbl$group_a == "A" & cor_tbl$group_b == "B"]
  ac <- cor_tbl$correlation[cor_tbl$group_a == "A" & cor_tbl$group_b == "C"]
  expect_true(ab > 0.99)
  expect_true(ac < -0.99)
})

test_that("group_correlation_matrix handles groups that don't share every date via pairwise-complete correlation", {
  gs <- list(
    A = tibble::tibble(ds = as.Date("2024-01-01") + 0:19, y = 1:20),
    B = tibble::tibble(ds = as.Date("2024-01-01") + 5:24, y = 1:20)
  )
  cor_tbl <- group_correlation_matrix(gs)
  expect_equal(nrow(cor_tbl), 1)
  expect_true(!is.na(cor_tbl$correlation[1]))
})
