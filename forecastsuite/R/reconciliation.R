# Bottom-up hierarchical reconciliation: sums the already-fit per-group
# forecasts (and their actuals) instead of fitting the aggregate
# separately. The sum of individually-coherent group forecasts is itself
# always coherent by construction -- no reconciliation algorithm or extra
# model fit needed, just addition.
#
# Point forecasts sum exactly: E[sum(y_g)] = sum(E[y_g]), so summing yhat
# across groups is mathematically correct, not an approximation.
#
# Prediction intervals do NOT sum exactly in general: summing
# yhat_lower/yhat_upper across groups implicitly assumes each group's
# forecast error is perfectly positively correlated with every other
# group's, which is rarely literally true (independent/uncorrelated group
# errors would make the true combined interval narrower than this sum).
# This is nonetheless the standard, defensible heuristic used for
# bottom-up interval aggregation in practice -- flagged here as a known
# simplification, not treated as a bug.
#
#' Bottom-up hierarchical reconciliation
#'
#' Sums already-fit per-group forecasts (and their actuals) instead of
#' fitting the aggregate separately -- the sum of individually-coherent
#' group forecasts is itself always coherent by construction. Point
#' forecasts sum exactly; prediction intervals are summed too, under the
#' standard (if approximate) bottom-up assumption that group forecast
#' errors are perfectly correlated -- flagged as a known simplification,
#' not a bug.
#'
#' @param fits A named list of fit-result lists (one per group), each with
#'   `$fc_tib` (a tibble with `ds`, `yhat`, and optionally
#'   `yhat_lower`/`yhat_upper`) and `$train`/`$test` (tibbles with `ds`,
#'   `y`). A `NULL` entry is dropped; a present entry missing a field is
#'   skipped for that field only, rather than erroring the whole
#'   reconciliation.
#'
#' @return A list with `fc_tib`, `train`, `test` (each summed by `ds` across
#'   groups, or `NULL` if no group supplied that field), and `components`
#'   (the names of the groups that were actually combined).
#' @export
#' @examples
#' ds <- as.Date("2024-01-01") + 0:2
#' fits <- list(
#'   A = list(fc_tib = tibble::tibble(ds = ds, yhat = c(10, 11, 12)),
#'            train = tibble::tibble(ds = ds, y = c(9, 10, 11))),
#'   B = list(fc_tib = tibble::tibble(ds = ds, yhat = c(1, 2, 3)),
#'            train = tibble::tibble(ds = ds, y = c(1, 1, 1)))
#' )
#' reconcile_bottom_up(fits)
reconcile_bottom_up <- function(fits) {
  fits <- fits[!vapply(fits, is.null, logical(1))]
  if (length(fits) < 1) stop("No fitted groups to reconcile.", call. = FALSE)

  sum_by_ds <- function(field, cols) {
    parts <- lapply(fits, `[[`, field)
    parts <- parts[!vapply(parts, is.null, logical(1))]
    if (!length(parts)) return(NULL)
    present <- intersect(cols, Reduce(intersect, lapply(parts, names)))
    if (!length(present)) return(NULL)
    dplyr::bind_rows(parts) |>
      dplyr::group_by(ds) |>
      dplyr::summarise(dplyr::across(dplyr::all_of(present), ~ sum(.x, na.rm = FALSE)),
                        .groups = "drop") |>
      dplyr::arrange(ds)
  }

  list(
    fc_tib     = sum_by_ds("fc_tib", c("yhat", "yhat_lower", "yhat_upper")),
    train      = sum_by_ds("train",  "y"),
    test       = sum_by_ds("test",   "y"),
    components = names(fits)
  )
}

# Top-down reconciliation needs a genuinely independent aggregate-level
# forecast (fit directly on the summed series), not one derived from the
# already-fit group forecasts -- summing group forecasts back up is exactly
# what reconcile_bottom_up() already is, so a "top-down" that reused it
# would just be bottom-up under a different name. The caller (the bundled
# app's server) fits the aggregate once, alongside the per-group fits, only
# when Top-down is selected.
#
#' Top-down hierarchical reconciliation (historical proportions)
#'
#' Disaggregates one already-fit aggregate-level forecast down to each
#' group by that group's fixed historical share of the total, instead of
#' fitting (or summing) each group's own forecast shape the way
#' [reconcile_bottom_up()] does. Coherent by construction (the shares sum
#' to 1), and a meaningfully different result from bottom-up whenever the
#' aggregate-level model captures dynamics the per-group models miss (or
#' vice versa) -- not just the same total recomputed a different way.
#'
#' @param fits A named list of fit-result lists (one per group), each with
#'   `$train` (a tibble with `ds`/`y`) used only to compute historical
#'   proportions -- `$fc_tib` is not used here (unlike
#'   [reconcile_bottom_up()], which sums it). A `NULL` entry is dropped. A
#'   group whose historical total is zero/NA falls back to an equal share
#'   rather than a zero share.
#' @param aggregate_forecast A tibble with `ds`/`yhat` columns (and
#'   optionally `yhat_lower`/`yhat_upper`) -- a forecast fit directly on
#'   the summed series, not derived from `fits`.
#'
#' @return A list with `fc_tib` (`aggregate_forecast`'s own columns,
#'   unchanged -- the top-down total *is* the aggregate-level forecast),
#'   `train`/`test` (`NULL`; the caller already has the aggregate-level
#'   train/test that produced `aggregate_forecast` and should use those
#'   directly for display), `components` (the names of the groups whose
#'   historical shares were used), and `proportions` (a named list, one
#'   fixed share per group, summing to 1).
#' @export
#' @examples
#' ds <- as.Date("2024-01-01") + 0:2
#' fits <- list(
#'   A = list(train = tibble::tibble(ds = ds, y = c(9, 10, 11))),
#'   B = list(train = tibble::tibble(ds = ds, y = c(1, 1, 1)))
#' )
#' aggregate_forecast <- tibble::tibble(ds = ds, yhat = c(10, 11, 12))
#' reconcile_top_down(fits, aggregate_forecast)
reconcile_top_down <- function(fits, aggregate_forecast) {
  fits <- fits[!vapply(fits, is.null, logical(1))]
  if (length(fits) < 1) stop("No fitted groups to reconcile.", call. = FALSE)
  if (is.null(aggregate_forecast) || !all(c("ds", "yhat") %in% names(aggregate_forecast))) {
    stop("aggregate_forecast must have 'ds' and 'yhat' columns.", call. = FALSE)
  }

  shares <- vapply(fits, function(f) {
    if (is.null(f$train) || !"y" %in% names(f$train)) return(NA_real_)
    sum(f$train$y, na.rm = TRUE)
  }, numeric(1))
  total_share <- sum(shares, na.rm = TRUE)
  if (!is.finite(total_share) || total_share == 0) {
    shares[] <- 1
    total_share <- sum(shares)
  }
  shares[is.na(shares)] <- 0
  proportions <- shares / total_share

  cols <- intersect(c("yhat", "yhat_lower", "yhat_upper"), names(aggregate_forecast))

  list(
    fc_tib      = aggregate_forecast[c("ds", cols)],
    train       = NULL,
    test        = NULL,
    components  = names(fits),
    proportions = stats::setNames(as.list(proportions), names(fits))
  )
}
