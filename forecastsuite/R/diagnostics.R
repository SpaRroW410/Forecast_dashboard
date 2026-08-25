# Analysis features that go beyond point-metrics/model-fitting: residual
# diagnostics (is the fitted model's error genuinely unpredictable, or is
# there structure left over?), seasonal decomposition (surfacing the STL
# split that recommend.R's analyze_series() already computes internally but
# never shows), anomaly/outlier detection on the raw series (a statistical
# check, distinct from the holidays tab's rules-based calendar-vs-declared
# consistency check), and cross-group correlation (only meaningful when a
# grouping column is active). Every function here is pure -- no Shiny
# dependency -- so each is unit-testable standalone; R/app_server.R wires
# them to reactives and R/plot_diagnostics.R renders them.

# Generic across every registered model: only needs fc_tib's ds/yhat and
# test_df's ds/y, exactly like metric_utils.R::compute_forecast_metrics()
# already does, so it works unmodified for any current or future model.
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

# Same NA-fill prep as recommend.R::analyze_series(), factored out isn't
# worth it for two lines -- kept in sync manually, covered by tests.
.fill_series <- function(y) {
  y_filled <- tryCatch(zoo::na.approx(y, na.rm = FALSE), error = function(e) y)
  y_filled[is.na(y_filled)] <- mean(y_filled, na.rm = TRUE)
  y_filled
}

# Surfaces the STL trend/seasonal/remainder split that analyze_series()
# already computes internally to drive the recommendation heuristic, as a
# tidy tibble a caller can plot directly. NULL (not an error) when no
# candidate frequency has enough cycles of data, or date_agg has no
# seasonal candidates at all (e.g. "year") -- callers show an informative
# message rather than a plot in that case.
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

# Flags unusual points in the raw series -- distinct from the holidays tab's
# consistency check (calendar-vs-declared-holiday mismatch), this is a
# statistical check on the values themselves. Uses the STL remainder when
# decompose_series() finds one (isolates unusual points from normal
# trend/seasonal movement, which a raw-value check can't); falls back to
# deviation from a running median when no seasonal decomposition applies
# (short series, yearly aggregation, etc.), so it still works on every
# series shape.
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

# Pairwise correlation between every configured group's series, aligned on
# ds (pairwise-complete, so groups that don't share every period still
# compare on their overlap). Upper triangle only, no self-pairs -- one row
# per distinct pair, for both a table and a heatmap to consume.
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
