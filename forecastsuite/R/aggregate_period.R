# Collapsing multiple rows that fall in the same period.
#
# process_uploaded_data(type = "agg") assumes the uploaded table already
# holds exactly one row per period -- it renames and sorts but never
# groups. Real tables frequently break that assumption: TB case data split
# by district, sex or age group has many rows per Year+Quarter, and
# leaving them un-collapsed yields a series with repeated ds values, which
# every model then treats as noise at a single timestamp.
#
# collapse_to_period() snaps each row to the start of its period and
# combines the duplicates. Sum is the default because the common case is
# counts; mean/median are offered for rates and indices, where summing
# across strata would be meaningless.

period_unit_for <- function(date_agg) {
  units <- c(hour = "hour", day = "day", week = "week",
              month = "month", quarter = "quarter", year = "year")
  if (is.null(date_agg) || !(date_agg %in% names(units))) return("day")
  units[[date_agg]]
}

#' Collapse multiple rows sharing a period into one
#'
#' Snaps each row's `ds` to the start of its period (per `date_agg`) and
#' combines rows that land on the same period (and, if `group_col` is
#' supplied, the same group) -- e.g. case data split by district/sex/age
#' with many rows per Year+Quarter.
#'
#' @param df A data frame with `ds` (date-like) and `y` (numeric) columns.
#' @param date_agg Aggregation frequency: one of `"hour"`, `"day"`,
#'   `"week"`, `"month"`, `"quarter"`, `"year"`.
#' @param fun How to combine rows sharing a period: `"sum"` (the default,
#'   for counts), `"mean"`/`"median"` (for rates/indices, where summing
#'   across strata would be meaningless), or `"none"` (return `df`
#'   unchanged).
#' @param group_col Optional character scalar; rows only collapse together
#'   if they share both a period and this column's value.
#'
#' @return A tibble with one row per period (and group, if `group_col` is
#'   supplied), columns `ds`/`y`(/`group_col`).
#' @export
#' @examples
#' df <- data.frame(ds = as.Date(c("2024-01-01", "2024-01-02")), y = c(3, 5))
#' collapse_to_period(df, date_agg = "month")
collapse_to_period <- function(df, date_agg = "day", fun = c("sum", "mean", "median", "none"),
                                group_col = NULL) {
  fun <- match.arg(fun)
  if (identical(fun, "none")) return(df)
  if (!all(c("ds", "y") %in% names(df))) {
    stop("collapse_to_period() expects a data frame with ds and y columns.", call. = FALSE)
  }

  unit <- period_unit_for(date_agg)
  f <- switch(fun,
    sum    = function(v) sum(v, na.rm = TRUE),
    mean   = function(v) mean(v, na.rm = TRUE),
    median = function(v) stats::median(v, na.rm = TRUE)
  )

  has_group <- !is.null(group_col) && group_col %in% names(df)
  group_keys <- if (has_group) c("ds", group_col) else "ds"

  df |>
    dplyr::mutate(ds = lubridate::floor_date(ds, unit = unit)) |>
    dplyr::group_by(dplyr::across(dplyr::all_of(group_keys))) |>
    dplyr::summarise(y = f(y), .groups = "drop") |>
    dplyr::arrange(ds)
}

#' Count how many rows share a period
#'
#' Used to tell the user what [collapse_to_period()] would do, before doing
#' it. With `group_col` supplied, rows only count as duplicates if they
#' share both a period and a group -- two different districts on the same
#' date are not a collision.
#'
#' @param df A data frame with a `ds` (date-like) column.
#' @param date_agg Aggregation frequency: one of `"hour"`, `"day"`,
#'   `"week"`, `"month"`, `"quarter"`, `"year"`.
#' @param group_col Optional character scalar, a grouping column.
#'
#' @return A single integer: how many rows would be removed by collapsing
#'   (`0` if none).
#' @export
#' @examples
#' df <- data.frame(ds = as.Date(c("2024-01-01", "2024-01-02")), y = c(3, 5))
#' count_duplicate_periods(df, date_agg = "month")
count_duplicate_periods <- function(df, date_agg = "day", group_col = NULL) {
  if (!("ds" %in% names(df)) || nrow(df) == 0) return(0L)
  unit <- period_unit_for(date_agg)
  snapped <- lubridate::floor_date(df$ds, unit = unit)
  has_group <- !is.null(group_col) && group_col %in% names(df)
  keys <- if (has_group) paste(snapped, df[[group_col]], sep = "\r") else snapped
  as.integer(length(keys) - length(unique(keys)))
}
