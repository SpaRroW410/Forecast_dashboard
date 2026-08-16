# Same lightweight, no-model-fitting heuristic as the hosted app's
# helpers/recommend_utils.R (see this package's README on why it's a
# separate copy), generalized to rank across every registered, available
# model instead of just Prophet/ARIMA.

analyze_series <- function(df, date_agg = "day") {
  y <- df$y
  n_obs <- length(y)

  y_filled <- tryCatch(zoo::na.approx(y, na.rm = FALSE), error = function(e) y)
  y_filled[is.na(y_filled)] <- mean(y_filled, na.rm = TRUE)

  candidate_freqs <- switch(date_agg,
    hour  = c(24, 168),
    day   = c(7, 365),
    week  = c(52),
    month = c(12),
    c(7)
  )

  trend_strength <- tryCatch(abs(stats::cor(y_filled, seq_along(y_filled))), error = function(e) 0)
  seasonal_strength <- 0
  detected_freq <- 1

  for (freq in candidate_freqs) {
    if (n_obs < 2 * freq) next
    ts_candidate <- stats::ts(y_filled, frequency = freq)
    decomp <- tryCatch(stats::stl(ts_candidate, s.window = "periodic"), error = function(e) NULL)
    if (is.null(decomp)) next

    comp <- decomp$time.series
    remainder <- comp[, "remainder"]
    trend_comp <- comp[, "trend"]
    seasonal_comp <- comp[, "seasonal"]
    var_r <- stats::var(remainder, na.rm = TRUE)
    candidate_seasonal_strength <- max(0, 1 - var_r / stats::var(seasonal_comp + remainder, na.rm = TRUE))

    if (candidate_seasonal_strength > seasonal_strength) {
      seasonal_strength <- candidate_seasonal_strength
      trend_strength <- max(0, 1 - var_r / stats::var(trend_comp + remainder, na.rm = TRUE))
      detected_freq <- freq
    }
  }

  ts_y <- stats::ts(y_filled, frequency = detected_freq)
  ndiffs_needed <- tryCatch(forecast::ndiffs(ts_y), error = function(e) NA_integer_)
  nsdiffs_needed <- if (detected_freq > 1) {
    tryCatch(forecast::nsdiffs(ts_y), error = function(e) NA_integer_)
  } else {
    0L
  }

  expected_step_secs <- c(hour = 3600, day = 86400, week = 604800, month = 2629800)[[date_agg]]
  span_secs <- as.numeric(difftime(max(df$ds), min(df$ds), units = "secs"))
  expected_n <- if (!is.na(expected_step_secs) && expected_step_secs > 0) {
    max(1, round(span_secs / expected_step_secs) + 1)
  } else {
    n_obs
  }
  missing_ratio <- max(0, 1 - n_obs / expected_n)

  list(
    n_obs             = n_obs,
    detected_freq     = detected_freq,
    n_cycles          = n_obs / detected_freq,
    trend_strength    = trend_strength,
    seasonal_strength = seasonal_strength,
    ndiffs_needed     = ndiffs_needed,
    nsdiffs_needed    = nsdiffs_needed,
    missing_ratio     = missing_ratio
  )
}

# Per-registry-key scoring functions (same heuristics as the hosted app's
# copy, keyed to match list_models()' `key` field rather than `label`).
.recommend_score_fns <- list(
  prophet = function(a, holidays_configured) {
    s <- 0.5; reasons <- character(0)
    if (holidays_configured) { s <- s + 0.3; reasons <- c(reasons, "holidays configured") }
    if (a$missing_ratio > 0.05) { s <- s + 0.2; reasons <- c(reasons, sprintf("%.0f%% missing dates", a$missing_ratio * 100)) }
    if (a$seasonal_strength > 0.4) { s <- s + 0.2; reasons <- c(reasons, "strong seasonality") }
    if (a$trend_strength > 0.5) { s <- s + 0.1; reasons <- c(reasons, "clear trend") }
    list(score = s, reasons = reasons)
  },
  arima = function(a, holidays_configured) {
    s <- 0.5; reasons <- character(0)
    if (a$missing_ratio < 0.02) { s <- s + 0.2; reasons <- c(reasons, "regular, mostly-complete series") }
    if (!is.na(a$ndiffs_needed) && a$ndiffs_needed <= 2) { s <- s + 0.2; reasons <- c(reasons, "well-behaved differencing") }
    if (a$seasonal_strength < 0.3) { s <- s + 0.1; reasons <- c(reasons, "weak/no seasonality") }
    if (holidays_configured) { s <- s - 0.2; reasons <- c(reasons, "does not model configured holidays") }
    list(score = s, reasons = reasons)
  },
  sarima = function(a, holidays_configured) {
    s <- 0.5; reasons <- character(0)
    if (a$missing_ratio < 0.02) { s <- s + 0.2; reasons <- c(reasons, "regular, mostly-complete series") }
    if (!is.na(a$ndiffs_needed) && a$ndiffs_needed <= 2) { s <- s + 0.2; reasons <- c(reasons, "well-behaved differencing") }
    if (a$seasonal_strength > 0.4 && a$n_cycles >= 2) { s <- s + 0.25; reasons <- c(reasons, "repeated seasonal cycles detected") }
    if (holidays_configured) { s <- s - 0.2; reasons <- c(reasons, "does not model configured holidays") }
    list(score = s, reasons = reasons)
  },
  ets = function(a, holidays_configured) {
    s <- 0.45; reasons <- character(0)
    if (a$n_cycles >= 2 && a$n_cycles < 8) { s <- s + 0.2; reasons <- c(reasons, "short-to-medium series, good general baseline") }
    if (a$seasonal_strength > 0.2 || a$trend_strength > 0.2) { s <- s + 0.15; reasons <- c(reasons, "smooth trend/seasonality") }
    if (holidays_configured) { s <- s - 0.15; reasons <- c(reasons, "does not model configured holidays") }
    list(score = s, reasons = reasons)
  },
  tbats = function(a, holidays_configured) {
    s <- 0.4; reasons <- character(0)
    if (a$seasonal_strength > 0.4 && a$detected_freq > 7) { s <- s + 0.3; reasons <- c(reasons, "complex/multiple seasonality suspected") }
    if (holidays_configured) { s <- s - 0.15; reasons <- c(reasons, "does not model configured holidays") }
    list(score = s, reasons = reasons)
  },
  nnetar = function(a, holidays_configured) {
    s <- 0.35; reasons <- character(0)
    if (a$n_obs > 500) { s <- s + 0.25; reasons <- c(reasons, "enough data for a neural net") }
    if (holidays_configured) { s <- s - 0.1; reasons <- c(reasons, "does not model configured holidays") }
    list(score = s, reasons = reasons)
  },
  holtwinters = function(a, holidays_configured) {
    s <- 0.4; reasons <- character(0)
    if (a$n_cycles >= 2 && a$seasonal_strength > 0.3) { s <- s + 0.2; reasons <- c(reasons, "clean seasonal pattern, classic method") }
    if (holidays_configured) { s <- s - 0.15; reasons <- c(reasons, "does not model configured holidays") }
    list(score = s, reasons = reasons)
  },
  lstm = function(a, holidays_configured) {
    s <- 0.3; reasons <- character(0)
    if (a$n_obs > 1000) { s <- s + 0.3; reasons <- c(reasons, "large dataset suits a neural net") }
    if (holidays_configured) { s <- s - 0.1; reasons <- c(reasons, "does not model configured holidays") }
    list(score = s, reasons = reasons)
  }
)

# candidates: vector of registry keys (e.g. c("prophet","arima")). Defaults
# to every currently-available registered model.
recommend_model <- function(analysis, holidays_configured = FALSE, candidates = NULL) {
  if (is.null(candidates)) {
    candidates <- vapply(list_models(available_only = TRUE), function(m) m$key, "")
  }

  rows <- lapply(candidates, function(key) {
    score_fn <- .recommend_score_fns[[key]]
    result <- if (is.null(score_fn)) {
      list(score = 0.3, reasons = character(0))
    } else {
      score_fn(analysis, holidays_configured)
    }
    label <- tryCatch(get_model(key)$label, error = function(e) key)
    reason <- if (length(result$reasons) == 0) "general-purpose fit" else paste(result$reasons, collapse = "; ")
    data.frame(model = label, key = key, score = result$score, reason = reason, stringsAsFactors = FALSE)
  })

  ranked <- do.call(rbind, rows)
  ranked[order(-ranked$score), ]
}
