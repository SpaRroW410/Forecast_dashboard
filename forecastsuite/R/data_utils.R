# Adapted from the parent repo's helpers/data_utils.R (same behavior,
# package-namespaced). See this package's README for why it's a copy
# rather than a shared source.

#' Turn an uploaded table into a ds/y forecasting series
#'
#' The Import tab's core transform: renames the user's chosen date/value
#' columns to `ds`/`y`, aggregates individual-observation data into periods,
#' and optionally normalizes by a population table to produce incidence
#' rather than absolute counts.
#'
#' @param data A data frame -- the uploaded main dataset.
#' @param type `"agg"` (each row is already one value per period) or
#'   `"individual"` (each row is a single event, counted per period).
#' @param date_col Character scalar, the name of `data`'s date column.
#' @param value_col Character scalar, the name of `data`'s value column
#'   (required when `type = "agg"`, ignored for `"individual"`).
#' @param group_col Optional character scalar, a grouping column (e.g.
#'   District) to carry through untouched alongside `ds`/`y`.
#' @param pop_df Optional population data frame for normalization.
#' @param pop_date_col,pop_value_col Character scalars naming `pop_df`'s key
#'   and value columns (required together with `pop_df` to normalize).
#' @param pop_group_col Optional character scalar, `pop_df`'s grouping
#'   column, if it has one.
#' @param unit_divisor,pop_multiplier Numeric scaling applied to the
#'   population figure (e.g. `unit_divisor = 100000` for per-100k).
#' @param date_agg Aggregation frequency: one of `"hour"`, `"day"`,
#'   `"week"`, `"month"`, `"quarter"`, `"year"`.
#' @param pop_freq Whether `pop_df`'s value is given `"year"`ly or
#'   `"month"`ly.
#'
#' @return A tibble with columns `ds`, `y`, and `group_col` if supplied.
#' @export
#' @examples
#' df <- data.frame(when = as.Date("2024-01-01") + 0:9, count = 1:10)
#' process_uploaded_data(df, type = "agg", date_col = "when", value_col = "count")
process_uploaded_data <- function(data,
                                   type = c("agg", "individual"),
                                   date_col,
                                   value_col = NULL,
                                   group_col = NULL,
                                   pop_df = NULL,
                                   pop_date_col = NULL,
                                   pop_value_col = NULL,
                                   pop_group_col = NULL,
                                   unit_divisor = 1,
                                   pop_multiplier = 1,
                                   date_agg = "day",
                                   pop_freq = "year") {

  type <- match.arg(type)
  # A grouping column (e.g. District) is untouched by rename()/mutate()/
  # filter()/arrange() below -- only summarise() (the "individual" branch)
  # and the trailing select() would silently drop it, so those two spots
  # are the only ones that need to know about it. `has_group` reflects
  # whether *this* call's `data` actually carries that column: the app
  # calls this function once with group_col set (per-group data) and once
  # with it NULL (the aggregate view), reusing the same pop_df/pop_group_col.
  has_group <- !is.null(group_col) && group_col %in% names(data)

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
      dplyr::mutate(ds = lubridate::floor_date(event_date, unit = date_agg))

    group_keys <- if (has_group) c("ds", group_col) else "ds"
    df <- df |>
      dplyr::group_by(dplyr::across(dplyr::all_of(group_keys))) |>
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

    # A population table with no group breakdown only ever normalizes the
    # aggregate view (guessing a national figure onto individual groups
    # would misrepresent incidence). A population table that DOES carry a
    # group column normalizes per-group data by matching (date, group);
    # for the aggregate view in that case, population is summed across
    # groups per date key rather than relying on a separately-supplied
    # total, so the two normalizations stay internally consistent.
    has_pop_group <- !is.null(pop_group_col) && pop_group_col %in% names(pop_df)
    if (has_pop_group && has_group) {
      pop_clean <- pop_clean |>
        dplyr::rename(.pop_group = !!rlang_sym(pop_group_col)) |>
        dplyr::mutate(.pop_group = as.character(.pop_group)) |>
        dplyr::group_by(date_key, .pop_group) |>
        dplyr::summarise(pop = sum(pop, na.rm = TRUE), .groups = "drop")
      df <- df |> dplyr::mutate(.pop_group = as.character(.data[[group_col]]))
      join_by <- c("agg_key" = "date_key", ".pop_group")
    } else if (has_pop_group) {
      pop_clean <- pop_clean |>
        dplyr::group_by(date_key) |>
        dplyr::summarise(pop = sum(pop, na.rm = TRUE), .groups = "drop")
      join_by <- c("agg_key" = "date_key")
    } else {
      join_by <- c("agg_key" = "date_key")
    }

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
      dplyr::left_join(pop_clean, by = join_by) |>
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

  select_cols <- if (has_group) c("ds", "y", group_col) else c("ds", "y")
  df <- df |>
    dplyr::select(dplyr::all_of(select_cols)) |>
    dplyr::arrange(ds)

  df
}

# Small internal wrapper avoiding a top-level `library(rlang)` call;
# dplyr already depends on rlang, so `dplyr::sym()` is always available.
rlang_sym <- function(x) dplyr::sym(x)
