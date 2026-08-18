# Starting-point hyperparameters derived from the same cheap diagnostics
# recommend_model() already computes (R/recommend.R).
#
# This is what replaces the hosted app's Prophet prior-grid comparison
# (four CP/seasonality combinations fit and compared): rather than fitting
# four models and picking a winner, the series' measured trend and
# seasonal strength suggest where to start, and the user can adjust from
# there. Cheaper, and it generalizes past Prophet to the ARIMA family.
#
# These are informed starting points, NOT optimal values. auto.arima still
# searches the ARIMA order space better than any heuristic; the suggested
# (p,d,q) matters mainly when someone wants to hand-tune, and d/D are the
# parts actually grounded in a statistical test (ndiffs/nsdiffs).

suggest_parameters <- function(analysis, model_key) {
  a <- analysis

  if (identical(model_key, "prophet")) {
    # Changepoint prior scales trend flexibility. A series whose variation
    # is dominated by trend needs more freedom; a flat one needs less, or
    # Prophet chases noise.
    cp <- if (a$trend_strength > 0.8) 0.15
          else if (a$trend_strength > 0.5) 0.05
          else 0.01
    season <- if (a$seasonal_strength > 0.6) 15
              else if (a$seasonal_strength > 0.3) 10
              else 3

    reasons <- c(
      sprintf("trend strength %.2f -> changepoint prior %.2f", a$trend_strength, cp),
      sprintf("seasonal strength %.2f -> seasonality prior %d", a$seasonal_strength, season)
    )
    return(list(
      params = list(cp = cp, season = season, holiday = 5),
      text = paste0("Suggested: changepoint prior ", cp, ", seasonality prior ", season),
      reasons = reasons
    ))
  }

  if (model_key %in% c("arima", "sarima")) {
    d <- if (is.na(a$ndiffs_needed)) 1L else as.integer(a$ndiffs_needed)
    D <- if (is.na(a$nsdiffs_needed)) 0L else as.integer(a$nsdiffs_needed)
    seasonal <- identical(model_key, "sarima")

    p <- if (is.null(a$arima_p) || is.na(a$arima_p)) 1L else as.integer(a$arima_p)
    q <- if (is.null(a$arima_q) || is.na(a$arima_q)) 1L else as.integer(a$arima_q)
    P <- if (!seasonal) 0L else if (is.null(a$arima_P) || is.na(a$arima_P)) 0L else as.integer(a$arima_P)
    Q <- if (!seasonal) 0L else if (is.null(a$arima_Q) || is.na(a$arima_Q)) 0L else as.integer(a$arima_Q)

    order_text <- sprintf("ARIMA(%d,%d,%d)", p, d, q)
    if (seasonal) {
      order_text <- sprintf("%s(%d,%d,%d)[%d]", order_text, P, D, Q, a$detected_freq)
    }

    reasons <- c(
      sprintf("ndiffs() suggests d = %d", d),
      if (seasonal) sprintf("nsdiffs() suggests D = %d at period %d", D, a$detected_freq),
      sprintf("PACF/ACF of the differenced series suggest p = %d, q = %d", p, q),
      if (seasonal) sprintf("seasonal-lag PACF/ACF suggest P = %d, Q = %d", P, Q),
      "these are starting points; auto-select will still search the order space better than a heuristic can"
    )
    return(list(
      params = list(order = c(p, d, q),
                     seasonal_order = if (seasonal) c(P, D, Q) else NULL),
      text = paste0("Suggested starting order: ", order_text),
      reasons = reasons[!vapply(reasons, is.null, logical(1))]
    ))
  }

  list(params = list(), text = "No tunable parameters -- fitted automatically.",
       reasons = character(0))
}

# One row per candidate model, so the recommendation table can carry a
# "suggested settings" column next to the score.
suggest_parameters_for <- function(analysis, model_keys) {
  vapply(model_keys, function(k) suggest_parameters(analysis, k)$text, character(1))
}
