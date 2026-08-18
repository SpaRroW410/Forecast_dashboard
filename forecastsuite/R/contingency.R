# Holiday / data consistency checks, ported from the hosted app's
# "Contingency Analysis" (server/server_holidays.R).
#
# Two complementary sanity checks on a declared holiday list:
#
#   holidays_with_data()  -- days declared as holidays that nonetheless
#       carry non-zero values. Usually means either the holiday was not
#       actually observed at that site, or data entry continued anyway.
#
#   always_zero_dates()   -- calendar dates (month-day) that are zero or
#       missing in *every* year present. These look like de facto
#       holidays/closures that were never declared, so a holiday-aware
#       model cannot account for them.

holidays_with_data <- function(holidays, data) {
  if (is.null(holidays) || nrow(holidays) == 0 ||
      is.null(data) || nrow(data) == 0) {
    return(tibble::tibble(ds = as.Date(character()), holiday = character(), y = numeric()))
  }

  h <- holidays
  d <- data
  h$ds <- as.Date(h$ds)
  d$ds <- as.Date(d$ds)

  dplyr::inner_join(h, d, by = "ds") |>
    dplyr::filter(!is.na(y), y > 0) |>
    dplyr::select(ds, holiday, y) |>
    dplyr::arrange(dplyr::desc(y))
}

always_zero_dates <- function(data, holidays = NULL) {
  if (is.null(data) || nrow(data) == 0) {
    return(tibble::tibble(ds = as.Date(character()), flag = character(),
                           declared_holiday = logical()))
  }

  d <- data
  d$ds <- as.Date(d$ds)

  by_md <- d |>
    dplyr::mutate(md = format(ds, "%m-%d")) |>
    dplyr::group_by(md) |>
    dplyr::summarise(
      all_zero    = all(y == 0, na.rm = TRUE) && any(!is.na(y)),
      all_missing = all(is.na(y)),
      .groups = "drop"
    ) |>
    dplyr::filter(all_zero | all_missing) |>
    dplyr::mutate(flag = ifelse(all_missing, "Missing every year", "Zero every year"))

  if (nrow(by_md) == 0) {
    return(tibble::tibble(ds = as.Date(character()), flag = character(),
                           declared_holiday = logical()))
  }

  years <- unique(lubridate::year(d$ds))
  out <- tidyr::crossing(by_md[, c("md", "flag")], year = years) |>
    dplyr::mutate(ds = suppressWarnings(as.Date(paste0(year, "-", md), format = "%Y-%m-%d"))) |>
    dplyr::filter(!is.na(ds)) |>
    dplyr::select(ds, flag) |>
    dplyr::arrange(ds)

  # Flagging whether each suspicious date is already declared turns this
  # from a list into an actionable one: undeclared entries are the gap.
  declared <- if (!is.null(holidays) && nrow(holidays) > 0) as.Date(holidays$ds) else as.Date(character())
  out$declared_holiday <- out$ds %in% declared
  out
}

holiday_contingency <- function(holidays, data) {
  list(
    with_data   = holidays_with_data(holidays, data),
    always_zero = always_zero_dates(data, holidays)
  )
}
