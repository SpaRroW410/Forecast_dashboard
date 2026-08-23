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
# fits: named list of fit-result lists (the shape fit_one()/the app's
# fs_fit_btn grouped branch produce), each with $fc_tib (ds, yhat[,
# yhat_lower, yhat_upper]) and $train (ds, y). Entries missing either are
# skipped for that field rather than erroring the whole reconciliation.
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
