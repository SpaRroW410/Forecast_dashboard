library(dplyr)
library(lubridate)

process_uploaded_data <- function(data,
                                  type = c("agg", "individual"),
                                  date_col,
                                  value_col = NULL,
                                  pop_df = NULL,
                                  pop_date_col = NULL,
                                  pop_value_col = NULL,
                                  unit_divisor = 1,
                                  pop_multiplier = 1,
                                  date_agg = "day",
                                  pop_freq = "year") {
  
  type <- match.arg(type)
  
  # ------------------------
  # 🧩 AGGREGATED TIME SERIES
  # ------------------------
  if (type == "agg") {
    df <- data
    
    if (!(date_col %in% names(df)) || !(value_col %in% names(df))) {
      stop("❌ Selected date or value column not found in uploaded main dataset.")
    }
    
    df <- df %>%
      rename(ds = !!sym(date_col), y = !!sym(value_col)) %>%
      mutate(
        ds = as.Date(ds),
        y = as.numeric(y)
      ) %>%
      filter(!is.na(ds), !is.na(y)) %>%
      arrange(ds)
  }
  
  # -------------------------
  # INDIVIDUAL OBSERVATION
  # -------------------------
  if (type == "individual") {
    df <- data
    
    if (!(date_col %in% names(df))) {
      stop("❌ Selected date column not found in uploaded main dataset.")
    }
    
    df <- df %>%
      rename(event_date = !!sym(date_col)) %>%
      mutate(event_date = as.Date(event_date), raw = 1) %>%
      filter(!is.na(event_date)) %>%
      mutate(ds = floor_date(event_date, unit = date_agg)) %>%
      group_by(ds) %>%
      summarise(count = sum(raw), .groups = "drop")
    
    df <- df %>%
      rename(y = count) %>%
      filter(!is.na(ds), !is.na(y))
  }
  
  # -------------------------------
  # POPULATION-NORMALIZED OUTPUT
  # -------------------------------
  if (!is.null(pop_df) && !is.null(pop_date_col) && !is.null(pop_value_col)) {
    
    if (!(pop_date_col %in% names(pop_df)) || !(pop_value_col %in% names(pop_df))) {
      stop("❌ Selected population date or value column not found in uploaded population dataset.")
    }
    
    pop_clean <- pop_df %>%
      rename(date_key = !!sym(pop_date_col), pop = !!sym(pop_value_col)) %>%
      mutate(
        date_key = as.character(date_key),
        pop = (as.numeric(pop) * pop_multiplier) / unit_divisor
      )
    
    df <- df %>%
      mutate(
        year = year(ds),
        month = month(ds),
        days_in_month = days_in_month(ds),
        agg_key = case_when(
          date_agg == "month" ~ format(ds, "%Y-%m"),
          TRUE ~ as.character(year(ds))
        )
      ) %>%
      left_join(pop_clean, by = c("agg_key" = "date_key")) %>%
      mutate(
        time_multiplier = case_when(
          date_agg == "day" & pop_freq == "year"  ~ if_else(leap_year(year), 366, 365),
          date_agg == "day" & pop_freq == "month" ~ days_in_month,
          date_agg == "week" & pop_freq == "year" ~ 52.14,
          date_agg == "week" & pop_freq == "month" ~ days_in_month / 7,
          date_agg == "month" ~ 12,
          TRUE ~ 1
        ),
        y = (y * time_multiplier) / pop
      ) %>%
      filter(!is.na(ds), !is.na(y))
  }
  
  # ✅ Always return only ds and y
  df <- df %>%
    select(ds, y) %>%
    arrange(ds)
  
  return(df)
}