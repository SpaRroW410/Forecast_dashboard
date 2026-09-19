# Analysis features that go beyond point-metrics/model-fitting: residual
# diagnostics (is the fitted model's error genuinely unpredictable, or is
# there structure left over?), seasonal decomposition (surfacing the STL
# split that recommend.R's analyze_series() already computes internally but
# never shows), anomaly/outlier detection on the raw series (a statistical
# check, distinct from the holidays tab's rules-based calendar-vs-declared
# consistency check), prediction interval coverage, and cross-group
# correlation (only meaningful when a grouping column is active). Every
# function here is pure -- no Shiny dependency -- so each is unit-testable
# standalone; R/app_server.R wires them to reactives and
# R/plot_diagnostics.R renders them.

#' Residual diagnostics for a forecast
#'
#' Whether a fitted model's error looks like unpredictable noise, or still
#' has structure left in it: a Ljung-Box test for residual autocorrelation,
#' a Shapiro-Wilk normality test, and the residual ACF with its Box-Jenkins
#' confidence band. Generic across every registered model -- only needs
#' `fc_tib`'s `ds`/`yhat` and `test_df`'s `ds`/`y`.
#'
#' @param fc_tib A tibble with `ds`/`yhat` columns -- a model's forecast.
#' @param test_df A tibble with `ds`/`y` columns -- the held-out actuals.
#'
#' @return A list with `residuals` (tibble of `ds`/`resid`), `ljung_box_p`,
#'   `shapiro_p` (each `NA` if there isn't enough overlapping data),
#'   `acf_df` (tibble of `lag`/`acf`), `ci` (the confidence bound), and `n`.
#' @export
#' @examples
#' ds <- as.Date("2024-01-01") + 0:29
#' fc_tib <- tibble::tibble(ds = ds, yhat = 100)
#' test_df <- tibble::tibble(ds = ds, y = 100 + rnorm(30))
#' compute_residual_diagnostics(fc_tib, test_df)
compute_residual_diagnostics <- function(fc_tib, test_df) {
  joined <- dplyr::inner_join(fc_tib, test_df, by = "ds")
  resid <- joined$y - joined$yhat
  n <- length(resid)

  residuals_df <- tibble::tibble(ds = joined$ds, resid = resid)

  # Ljung-Box needs enough lags to be meaningful; below this it's not a
  # useful test, just a noisy p-value.
  ljung_box_p <- if (n >= 8) {
    lag <- max(1, min(10, floor(n / 5)))
    tryCatch(stats::Box.test(resid, type = "Ljung-Box", lag = lag)$p.value,
             error = function(e) NA_real_)
  } else {
    NA_real_
  }

  # shapiro.test() only accepts 3-5000 observations.
  shapiro_p <- if (n >= 3 && n <= 5000) {
    tryCatch(stats::shapiro.test(resid)$p.value, error = function(e) NA_real_)
  } else {
    NA_real_
  }

  # Same 1.96/sqrt(n) Box-Jenkins confidence bound already used in
  # recommend.R::.suggest_pq() -- reused, not re-derived.
  ci <- if (n > 0) 1.96 / sqrt(n) else NA_real_

  acf_df <- if (n >= 2) {
    acf_res <- tryCatch(stats::acf(resid, plot = FALSE, na.action = stats::na.pass),
                         error = function(e) NULL)
    if (is.null(acf_res) || length(acf_res$acf) < 2) {
      tibble::tibble(lag = integer(), acf = double())
    } else {
      # Drop lag 0 (always 1, not meaningful against a confidence band).
      tibble::tibble(
        lag = as.integer(acf_res$lag[-1, 1, 1]),
        acf = as.numeric(acf_res$acf[-1, 1, 1])
      )
    }
  } else {
    tibble::tibble(lag = integer(), acf = double())
  }

  list(residuals = residuals_df, ljung_box_p = ljung_box_p,
       shapiro_p = shapiro_p, acf_df = acf_df, ci = ci, n = n)
}

#' Empirical prediction-interval coverage
#'
#' Whether a model's uncertainty bounds are honest, not just its point
#' forecast: what fraction of actuals actually fell inside
#' `yhat_lower`/`yhat_upper`, versus the interval's nominal confidence
#' level (Prophet and the `forecast`-package adapters default to an 80%
#' interval).
#'
#' @param fc_tib A tibble with `ds`/`yhat` columns, and typically
#'   `yhat_lower`/`yhat_upper`. Models with no interval columns (e.g.
#'   NNETAR without `PI = TRUE`) return `NA` coverage rather than erroring.
#' @param test_df A tibble with `ds`/`y` columns -- the held-out actuals.
#' @param nominal_level Numeric, the interval's nominal confidence level.
#'   Default `0.8`.
#'
#' @return A list with `empirical_coverage`, `nominal_level`, `gap`
#'   (`empirical_coverage - nominal_level`), and `n`.
#' @export
#' @examples
#' ds <- as.Date("2024-01-01") + 0:9
#' fc_tib <- tibble::tibble(ds = ds, yhat = 10, yhat_lower = 9, yhat_upper = 11)
#' test_df <- tibble::tibble(ds = ds, y = c(rep(10, 8), 20, 20))
#' compute_interval_coverage(fc_tib, test_df)
compute_interval_coverage <- function(fc_tib, test_df, nominal_level = 0.8) {
  if (!all(c("yhat_lower", "yhat_upper") %in% names(fc_tib))) {
    return(list(empirical_coverage = NA_real_, nominal_level = nominal_level,
                gap = NA_real_, n = 0L))
  }
  joined <- dplyr::inner_join(fc_tib, test_df, by = "ds")
  if (nrow(joined) == 0) {
    return(list(empirical_coverage = NA_real_, nominal_level = nominal_level,
                gap = NA_real_, n = 0L))
  }
  covered <- joined$y >= joined$yhat_lower & joined$y <= joined$yhat_upper
  empirical_coverage <- mean(covered, na.rm = TRUE)
  list(empirical_coverage = empirical_coverage, nominal_level = nominal_level,
       gap = empirical_coverage - nominal_level, n = nrow(joined))
}

# Same NA-fill prep as recommend.R::analyze_series(), factored out isn't
# worth it for two lines -- kept in sync manually, covered by tests.
.fill_series <- function(y) {
  y_filled <- tryCatch(zoo::na.approx(y, na.rm = FALSE), error = function(e) y)
  y_filled[is.na(y_filled)] <- mean(y_filled, na.rm = TRUE)
  y_filled
}

#' Seasonal decomposition of a series
#'
#' Surfaces the STL trend/seasonal/remainder split that `analyze_series()`
#' already computes internally to drive the recommendation heuristic, as a
#' tidy tibble a caller can plot directly.
#'
#' @param df A tibble with `ds`/`y` columns.
#' @param date_agg Aggregation frequency: one of `"hour"`, `"day"`,
#'   `"week"`, `"month"`, `"quarter"`, `"year"`.
#'
#' @return A tibble with columns `ds`, `observed`, `trend`, `seasonal`,
#'   `remainder`, or `NULL` (not an error) when no candidate frequency has
#'   enough cycles of data, or `date_agg` has no seasonal candidates at all
#'   (e.g. `"year"`).
#' @export
#' @examples
#' n <- 60
#' df <- tibble::tibble(ds = as.Date("2024-01-01") + 0:(n - 1),
#'                       y = 100 + 10 * sin(2 * pi * seq_len(n) / 7) + rnorm(n))
#' decompose_series(df, date_agg = "day")
decompose_series <- function(df, date_agg = "day") {
  y_filled <- .fill_series(df$y)
  best <- .detect_seasonal_decomp(y_filled, date_agg)
  if (is.null(best)) return(NULL)

  comp <- best$stl_fit$time.series
  tibble::tibble(
    ds        = df$ds,
    observed  = as.numeric(y_filled),
    trend     = as.numeric(comp[, "trend"]),
    seasonal  = as.numeric(comp[, "seasonal"]),
    remainder = as.numeric(comp[, "remainder"])
  )
}

#' Flag unusual points in a series
#'
#' A statistical check on the values themselves -- distinct from the
#' Holidays tab's consistency check (calendar-vs-declared-holiday
#' mismatch). Uses the STL remainder when [decompose_series()] finds one
#' (isolates unusual points from normal trend/seasonal movement, which a
#' raw-value check can't); falls back to deviation from a running median
#' when no seasonal decomposition applies (short series, yearly
#' aggregation, etc.), so it still works on every series shape.
#'
#' @param df A tibble with `ds`/`y` columns.
#' @param date_agg Aggregation frequency: one of `"hour"`, `"day"`,
#'   `"week"`, `"month"`, `"quarter"`, `"year"`.
#' @param method `"iqr"` (the default) flags points outside
#'   `threshold * IQR` from the quartiles; `"zscore"` flags points more
#'   than `threshold` standard deviations from the mean.
#' @param threshold Numeric sensitivity threshold. Default `1.5`.
#'
#' @return A tibble with columns `ds`, `y`, `score` (the value the
#'   threshold was applied to), and `is_anomaly` (logical).
#' @export
#' @examples
#' df <- tibble::tibble(ds = as.Date("2024-01-01") + 0:29, y = c(rep(10, 29), 100))
#' detect_anomalies(df, date_agg = "day", method = "iqr")
detect_anomalies <- function(df, date_agg = "day", method = c("iqr", "zscore"), threshold = 1.5) {
  method <- match.arg(method)
  y_filled <- .fill_series(df$y)
  n <- length(y_filled)

  decomp <- decompose_series(df, date_agg)
  score_input <- if (!is.null(decomp)) {
    decomp$remainder
  } else if (n >= 5) {
    k <- max(3, n %/% 10)
    if (k %% 2 == 0) k <- k + 1
    if (k >= n) k <- if (n %% 2 == 0) n - 1 else n
    baseline <- tryCatch(stats::runmed(y_filled, k = k),
                          error = function(e) rep(mean(y_filled, na.rm = TRUE), n))
    y_filled - baseline
  } else {
    y_filled - mean(y_filled, na.rm = TRUE)
  }

  is_anomaly <- if (method == "iqr") {
    q <- stats::quantile(score_input, probs = c(0.25, 0.75), na.rm = TRUE)
    iqr <- q[2] - q[1]
    lower <- q[1] - threshold * iqr
    upper <- q[2] + threshold * iqr
    score_input < lower | score_input > upper
  } else {
    s <- stats::sd(score_input, na.rm = TRUE)
    if (!is.finite(s) || s == 0) {
      rep(FALSE, n)
    } else {
      abs((score_input - mean(score_input, na.rm = TRUE)) / s) > threshold
    }
  }

  tibble::tibble(
    ds = df$ds,
    y = df$y,
    score = as.numeric(score_input),
    is_anomaly = ifelse(is.na(is_anomaly), FALSE, is_anomaly)
  )
}

#' Pairwise correlation between grouped series
#'
#' Correlation between every pair of configured groups' series, aligned on
#' `ds` (pairwise-complete, so groups that don't share every period still
#' compare on their overlap).
#'
#' @param grouped_series_list A named list of `ds`/`y` tibbles, one per
#'   group (e.g. the app's `grouped_series()`).
#'
#' @return A tibble with columns `group_a`, `group_b`, `correlation` --
#'   upper triangle only, no self-pairs, one row per distinct pair. Empty
#'   if fewer than 2 groups are supplied.
#' @export
#' @examples
#' ds <- as.Date("2024-01-01") + 0:9
#' groups <- list(
#'   A = tibble::tibble(ds = ds, y = 1:10),
#'   B = tibble::tibble(ds = ds, y = 10:1)
#' )
#' group_correlation_matrix(groups)
group_correlation_matrix <- function(grouped_series_list) {
  empty <- tibble::tibble(group_a = character(), group_b = character(), correlation = double())
  if (is.null(grouped_series_list) || length(grouped_series_list) < 2) return(empty)

  group_names <- names(grouped_series_list)
  wide <- dplyr::bind_rows(grouped_series_list, .id = "group") |>
    tidyr::pivot_wider(names_from = "group", values_from = "y")

  present <- intersect(group_names, names(wide))
  if (length(present) < 2) return(empty)

  mat <- as.matrix(wide[, present, drop = FALSE])
  cor_mat <- stats::cor(mat, use = "pairwise.complete.obs")

  pairs <- utils::combn(present, 2, simplify = FALSE)
  rows <- lapply(pairs, function(p) {
    tibble::tibble(group_a = p[1], group_b = p[2], correlation = cor_mat[p[1], p[2]])
  })
  dplyr::bind_rows(rows)
}
