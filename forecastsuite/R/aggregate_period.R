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

collapse_to_period <- function(df, date_agg = "day", fun = c("sum", "mean", "median", "none")) {
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

  df |>
    dplyr::mutate(ds = lubridate::floor_date(ds, unit = unit)) |>
    dplyr::group_by(ds) |>
    dplyr::summarise(y = f(y), .groups = "drop") |>
    dplyr::arrange(ds)
}

# How many rows would be collapsed -- used to tell the user what happened
# instead of silently changing their row count.
count_duplicate_periods <- function(df, date_agg = "day") {
  if (!("ds" %in% names(df)) || nrow(df) == 0) return(0L)
  unit <- period_unit_for(date_agg)
  snapped <- lubridate::floor_date(df$ds, unit = unit)
  as.integer(length(snapped) - length(unique(snapped)))
}
