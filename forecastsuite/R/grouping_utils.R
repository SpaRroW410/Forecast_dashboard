# Splitting a long-format ds/y[/group] tibble into a named list of
# per-group ds/y tibbles, the shape plot_model_comparison()/
# render_comparison_png() already consume (they were built for "one
# dataset, many models" but are name-agnostic, so the same shape works
# for "one model, many groups").

split_by_group <- function(df, group_col) {
  if (is.null(group_col) || !(group_col %in% names(df))) return(NULL)
  keys <- as.character(df[[group_col]])
  stats::setNames(
    split(df[c("ds", "y")], keys),
    sort(unique(keys))
  )
}

# Real-world grouping columns are often messy: "female"/"Female"/"FEMALE"
# in the same column, meant to be one group, not three. Builds a
# raw-value -> canonical-label mapping (one row per distinct raw value)
# that the Import tab's "Merge / relabel values" table starts from and the
# user can further edit by hand.
#
# raw_values: the full column (with repeats) -- frequency matters, since
# the most common casing/spacing variant is used as each cluster's
# canonical label (a tie is broken by whichever appears first).
# merge_case: when TRUE, values that are identical after trimws()+tolower()
# collapse into one label; when FALSE, every distinct raw value keeps its
# own label (today's behavior before this feature existed).
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
