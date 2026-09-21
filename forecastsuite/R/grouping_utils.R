# Splitting a long-format ds/y[/group] tibble into a named list of
# per-group ds/y tibbles, the shape plot_model_comparison()/
# render_comparison_png() already consume (they were built for "one
# dataset, many models" but are name-agnostic, so the same shape works
# for "one model, many groups").

#' Split a ds/y/group tibble into one tibble per group
#'
#' @param df A data frame with `ds`, `y`, and `group_col` columns.
#' @param group_col Character scalar, the grouping column's name, or `NULL`
#'   (returns `NULL` -- no grouping).
#'
#' @return A named list of `ds`/`y` tibbles, one per distinct value of
#'   `group_col` (names sorted), or `NULL` if `group_col` is `NULL` or not
#'   present in `df`.
#' @export
#' @examples
#' df <- data.frame(ds = as.Date("2024-01-01") + 0:3,
#'                   y = 1:4, District = c("A", "A", "B", "B"))
#' split_by_group(df, "District")
split_by_group <- function(df, group_col) {
  if (is.null(group_col) || !(group_col %in% names(df))) return(NULL)
  keys <- as.character(df[[group_col]])
  stats::setNames(
    split(df[c("ds", "y")], keys),
    sort(unique(keys))
  )
}

#' Build a raw-value -> canonical-label map for a grouping column
#'
#' Real-world grouping columns are often messy: `"female"`/`"Female"`/
#' `"FEMALE"` in the same column, meant to be one group, not three. Builds a
#' raw-value -> canonical-label mapping (one row per distinct raw value)
#' that the Import tab's "Merge / relabel values" table starts from and the
#' user can further edit by hand.
#'
#' @param raw_values The full grouping column, with repeats -- frequency
#'   matters, since the most common casing/spacing variant becomes each
#'   cluster's canonical label (ties broken by whichever appears first).
#' @param merge_case Logical; if `TRUE` (the default), values identical
#'   after `trimws()`+`tolower()` collapse into one label; if `FALSE`,
#'   every distinct raw value keeps its own label.
#'
#' @return A tibble with columns `raw` (every distinct input value) and
#'   `label` (its canonical label).
#' @export
#' @examples
#' compute_group_value_map(c("female", "Female", "male"))
compute_group_value_map <- function(raw_values, merge_case = TRUE) {
  raw_values <- as.character(raw_values)
  raw_values <- raw_values[!is.na(raw_values)]
  if (!length(raw_values)) return(tibble::tibble(raw = character(), label = character()))

  counts <- dplyr::count(tibble::tibble(raw = raw_values), raw, name = "n")

  if (!isTRUE(merge_case)) {
    return(tibble::tibble(raw = counts$raw, label = counts$raw))
  }

  counts$cluster_key <- trimws(tolower(counts$raw))
  labeled <- counts |>
    dplyr::group_by(cluster_key) |>
    dplyr::mutate(label = raw[which.max(n)]) |>
    dplyr::ungroup()
  tibble::tibble(raw = labeled$raw, label = labeled$label)
}
