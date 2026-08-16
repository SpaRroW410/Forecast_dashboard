# Adapted from the parent repo's helpers/data_utils.R (same behavior,
# package-namespaced). See this package's README for why it's a copy
# rather than a shared source.

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

  if (type == "agg") {
    df <- data

    if (!(date_col %in% names(df)) || !(value_col %in% names(df))) {
      stop("Selected date or value column not found in uploaded main dataset.")
    }

    df <- df |>
      dplyr::rename(ds = !!rlang_sym(date_col), y = !!rlang_sym(value_col)) |>
      dplyr::mutate(
        ds = as.POSIXct(ds),
        y = as.numeric(y)
      ) |>
      dplyr::filter(!is.na(ds), !is.na(y)) |>
      dplyr::arrange(ds)
  }

  if (type == "individual") {
    df <- data

    if (!(date_col %in% names(df))) {
      stop("Selected date column not found in uploaded main dataset.")
    }

    df <- df |>
      dplyr::rename(event_date = !!rlang_sym(date_col)) |>
      dplyr::mutate(event_date = as.POSIXct(event_date), raw = 1) |>
      dplyr::filter(!is.na(event_date)) |>
      dplyr::mutate(ds = lubridate::floor_date(event_date, unit = date_agg)) |>
      dplyr::group_by(ds) |>
      dplyr::summarise(count = sum(raw), .groups = "drop") |>
      dplyr::rename(y = count) |>
      dplyr::filter(!is.na(ds), !is.na(y))
  }

  if (!is.null(pop_df) && !is.null(pop_date_col) && !is.null(pop_value_col)) {

    if (!(pop_date_col %in% names(pop_df)) || !(pop_value_col %in% names(pop_df))) {
      stop("Selected population date or value column not found in uploaded population dataset.")
    }

    pop_clean <- pop_df |>
      dplyr::rename(date_key = !!rlang_sym(pop_date_col), pop = !!rlang_sym(pop_value_col)) |>
      dplyr::mutate(
        date_key = as.character(date_key),
        pop = (as.numeric(pop) * pop_multiplier) / unit_divisor
      )

    df <- df |>
      dplyr::mutate(
        year = lubridate::year(ds),
        month = lubridate::month(ds),
        day = lubridate::day(ds),
        hour = lubridate::hour(ds),
        days_in_month = lubridate::days_in_month(ds),
        agg_key = dplyr::case_when(
          date_agg == "month" ~ format(ds, "%Y-%m"),
          date_agg == "week"  ~ as.character(lubridate::year(ds)),
          date_agg == "day"   ~ as.character(lubridate::year(ds)),
          date_agg == "hour"  ~ format(ds, "%Y-%m-%d"),
          TRUE ~ as.character(lubridate::year(ds))
        )
      ) |>
      dplyr::left_join(pop_clean, by = c("agg_key" = "date_key")) |>
      dplyr::mutate(
        time_multiplier = dplyr::case_when(
          date_agg == "hour" & pop_freq == "year"  ~ 365.25 * 24,
          date_agg == "hour" & pop_freq == "month" ~ days_in_month * 24,
          date_agg == "day"  & pop_freq == "year"  ~ 365.25,
          date_agg == "day"  & pop_freq == "month" ~ days_in_month,
          date_agg == "week" & pop_freq == "year"  ~ 365.25 / 7,
          date_agg == "week" & pop_freq == "month" ~ days_in_month / 7,
          date_agg == "month"                      ~ 12,
          TRUE                                     ~ 1
        ),
        y = ifelse(is.na(pop) | pop == 0, NA, (y * time_multiplier) / pop)
      ) |>
      dplyr::filter(!is.na(ds), !is.na(y))

    if (any(is.na(df$pop))) {
      warning("Some population values could not be matched. Check your date keys.")
    }
  }

  df <- df |>
    dplyr::select(ds, y) |>
    dplyr::arrange(ds)

  df
}

# Small internal wrapper avoiding a top-level `library(rlang)` call;
# dplyr already depends on rlang, so `dplyr::sym()` is always available.
rlang_sym <- function(x) dplyr::sym(x)
