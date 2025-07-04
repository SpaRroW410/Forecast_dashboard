generate_sundays <- function(ds_range) {
  seq.Date(min(ds_range), max(ds_range), by = "day") %>%
    as_tibble() %>%
    rename(ds = value) %>%
    filter(wday(ds) == 1) %>%
    mutate(holiday = "Sunday")
}

expand_fixed_holidays <- function(selected, years, label_map) {
  expand.grid(year = years, date = selected, stringsAsFactors = FALSE) %>%
    mutate(ds = as.Date(paste0(year, "-", date), format = "%Y-%m-%d")) %>%
    filter(!is.na(ds)) %>%
    mutate(holiday = label_map[date] |> unlist()) %>%
    select(ds, holiday)
}

parse_movable_holidays <- function(df, date_col, label_col) {
  df %>%
    mutate(
      ds = as.Date(.data[[date_col]]),
      holiday = as.character(.data[[label_col]])
    ) %>%
    filter(!is.na(ds), holiday != "") %>%
    select(ds, holiday)
}

apply_manual_entry <- function(existing_df, date, label, type, years = NULL) {
  if (type == "fixed") {
    month_day <- format(as.Date(date), "%m-%d")
    entries <- tibble(
      ds = as.Date(paste0(years, "-", month_day), format = "%Y-%m-%d"),
      holiday = label
    ) %>% filter(!is.na(ds))
  } else {
    entries <- tibble(ds = as.Date(date), holiday = label)
  }
  
  bind_rows(existing_df, entries) %>%
    distinct(ds, holiday, .keep_all = TRUE)
}

apply_label_edit <- function(df, row_index, new_label) {
  df$holiday[row_index] <- new_label
  df
}

apply_window_settings <- function(holiday_df, window_df) {
  holiday_df %>%
    left_join(window_df, by = "holiday") %>%
    mutate(
      lower_window = coalesce(lower_window, 0),
      upper_window = coalesce(upper_window, 0)
    ) %>%
    select(ds, holiday, lower_window, upper_window) %>%
    arrange(ds)
}