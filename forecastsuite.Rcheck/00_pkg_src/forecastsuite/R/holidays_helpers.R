# Adapted from the parent repo's helpers/holidays_helpers.R (same behavior,
# package-namespaced instead of top-level library() calls). See this
# package's README for why it's a copy rather than a shared source.

generate_sundays <- function(start_year, end_year) {
  all_days <- seq.Date(as.Date(paste0(start_year, "-01-01")),
                        as.Date(paste0(end_year, "-12-31")),
                        by = "day")
  sundays <- all_days[lubridate::wday(all_days) == 1]
  tibble::tibble(ds = sundays, holiday = "Sunday")
}

expand_fixed_holidays <- function(selected, years, label_map) {
  expand.grid(year = years, date = selected, stringsAsFactors = FALSE) |>
    dplyr::mutate(ds = suppressWarnings(as.Date(paste0(year, "-", date), format = "%Y-%m-%d"))) |>
    dplyr::filter(!is.na(ds)) |>
    dplyr::mutate(holiday = unlist(label_map[date]), holiday = as.character(holiday)) |>
    dplyr::select(ds, holiday)
}

parse_movable_holidays <- function(df, date_col, label_col) {
  stopifnot(all(c(date_col, label_col) %in% names(df)))

  df |>
    dplyr::mutate(
      ds = suppressWarnings(as.Date(.data[[date_col]])),
      holiday = stringr::str_trim(stringr::str_to_title(as.character(.data[[label_col]])))
    ) |>
    dplyr::filter(!is.na(ds), holiday != "") |>
    dplyr::select(ds, holiday)
}

apply_manual_entry <- function(store, date, label, type, years) {
  clean_label <- stringr::str_trim(stringr::str_to_title(label))

  if (type == "fixed") {
    expanded <- tibble::tibble(
      ds = suppressWarnings(as.Date(paste0(years, "-", format(date, "%m-%d")))),
      holiday = clean_label
    )
  } else {
    expanded <- tibble::tibble(ds = date, holiday = clean_label)
  }

  dplyr::bind_rows(store, expanded) |> dplyr::distinct()
}

apply_label_edit <- function(df, selected, new_label) {
  clean_label <- stringr::str_trim(stringr::str_to_title(new_label))
  df[selected, "holiday"] <- clean_label
  df
}

apply_window_settings <- function(df, windows) {
  if (is.null(windows) || nrow(windows) == 0) {
    df$lower_window <- 0L
    df$upper_window <- 0L
    return(df)
  }

  df |>
    dplyr::left_join(windows, by = "holiday") |>
    dplyr::mutate(
      lower_window = ifelse(is.na(lower_window), 0L, lower_window),
      upper_window = ifelse(is.na(upper_window), 0L, upper_window)
    )
}

normalize_flag_column <- function(df) {
  if (!"flag" %in% names(df)) df$flag <- NA_character_
  df |> dplyr::mutate(flag = as.character(flag))
}
