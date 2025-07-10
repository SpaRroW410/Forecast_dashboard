# Required packages
library(dplyr)
library(lubridate)
library(tibble)
library(stringr)

# 📅 Generate Sundays for a range of years
generate_sundays <- function(start_year, end_year) {
  all_days <- seq.Date(as.Date(paste0(start_year, "-01-01")),
                       as.Date(paste0(end_year, "-12-31")),
                       by = "day")
  sundays <- all_days[lubridate::wday(all_days) == 1]
  tibble(ds = sundays, holiday = "Sunday")
}

# 🏛️ Expand fixed holiday codes to labeled dates across multiple years
expand_fixed_holidays <- function(selected, years, label_map) {
  expand.grid(year = years, date = selected, stringsAsFactors = FALSE) %>%
    mutate(ds = suppressWarnings(as.Date(paste0(year, "-", date), format = "%Y-%m-%d"))) %>%
    filter(!is.na(ds)) %>%
    mutate(holiday = unlist(label_map[date]), holiday = as.character(holiday)) %>%
    select(ds, holiday)
}

# 📦 Parse uploaded movable holiday data using selected columns
parse_movable_holidays <- function(df, date_col, label_col) {
  stopifnot(all(c(date_col, label_col) %in% names(df)))
  
  df %>%
    mutate(
      ds = suppressWarnings(as.Date(.data[[date_col]])),
      holiday = str_trim(str_to_title(as.character(.data[[label_col]])))
    ) %>%
    filter(!is.na(ds), holiday != "") %>%
    select(ds, holiday)
}

# ➕ Add manual holiday entry (single or across all years)
apply_manual_entry <- function(store, date, label, type, years) {
  clean_label <- str_trim(str_to_title(label))
  
  if (type == "fixed") {
    expanded <- tibble(
      ds = suppressWarnings(as.Date(paste0(years, "-", format(date, "%m-%d")))),
      holiday = clean_label
    )
  } else {
    expanded <- tibble(ds = date, holiday = clean_label)
  }
  
  bind_rows(store, expanded) %>% distinct()
}

# ✏️ Edit label at selected row
apply_label_edit <- function(df, selected, new_label) {
  clean_label <- str_trim(str_to_title(new_label))
  df[selected, "holiday"] <- clean_label
  df
}

# 📐 Merge window settings into holiday data
apply_window_settings <- function(df, windows) {
  if (is.null(windows) || nrow(windows) == 0) {
    df$lower_window <- 0L
    df$upper_window <- 0L
    return(df)
  }
  
  df %>%
    left_join(windows, by = "holiday") %>%
    mutate(
      lower_window = ifelse(is.na(lower_window), 0L, lower_window),
      upper_window = ifelse(is.na(upper_window), 0L, upper_window)
    )
}

# 🛡️ Ensure 'flag' column exists and is character
normalize_flag_column <- function(df) {
  if (!"flag" %in% names(df)) df$flag <- NA_character_
  df %>% mutate(flag = as.character(flag))
}