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
