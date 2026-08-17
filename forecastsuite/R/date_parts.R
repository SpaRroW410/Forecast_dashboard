# Building a date from separate calendar-part columns.
#
# Real-world tables often split the period across columns -- e.g. a Year
# column plus a Quarter or Month column, sometimes plus a Day column --
# rather than carrying one parseable date. compose_date_parts() assembles
# those into a single Date and reports the finest granularity present, so
# the caller can aggregate at that level (year+quarter -> quarterly,
# year+month -> monthly, and so on) instead of guessing.

# Accepts 1-4, "1".."4", "Q1".."Q4", "q3", "Quarter 2" -> integer 1-4.
parse_quarter <- function(x) {
  if (is.numeric(x)) return(as.integer(x))
  chr <- toupper(trimws(as.character(x)))
  num <- suppressWarnings(as.integer(gsub("[^0-9]", "", chr)))
  num
}

# Accepts 1-12, "01", "Jan", "JANUARY", "sept" -> integer 1-12.
parse_month <- function(x) {
  if (is.numeric(x)) return(as.integer(x))
  chr <- trimws(as.character(x))
  num <- suppressWarnings(as.integer(chr))
  if (!all(is.na(num))) return(num)

  lower <- tolower(chr)
  abbrev <- tolower(month.abb)
  full <- tolower(month.name)
  vapply(lower, function(v) {
    if (is.na(v) || !nzchar(v)) return(NA_integer_)
    hit <- which(abbrev == substr(v, 1, 3))
    if (length(hit) == 1) return(as.integer(hit))
    hit <- which(full == v)
    if (length(hit) == 1) return(as.integer(hit))
    NA_integer_
  }, integer(1), USE.NAMES = FALSE)
}

# year_col is required; supply at most one of quarter_col / month_col, and
# day_col only alongside month_col. Returns list(ds =<Date>, granularity =
# one of "year"/"quarter"/"month"/"day").
compose_date_parts <- function(df, year_col, quarter_col = NULL,
                                month_col = NULL, day_col = NULL) {
  if (is.null(year_col) || !nzchar(year_col) || !(year_col %in% names(df))) {
    stop("A Year column is required to build a date from parts.", call. = FALSE)
  }
  has <- function(x) !is.null(x) && nzchar(x) && x %in% names(df)

  if (has(quarter_col) && has(month_col)) {
    stop("Supply either a Quarter column or a Month column, not both.", call. = FALSE)
  }
  if (has(day_col) && !has(month_col)) {
    stop("A Day column also needs a Month column.", call. = FALSE)
  }

  year <- suppressWarnings(as.integer(df[[year_col]]))

  if (has(month_col)) {
    month <- parse_month(df[[month_col]])
    if (has(day_col)) {
      day <- suppressWarnings(as.integer(df[[day_col]]))
      granularity <- "day"
    } else {
      day <- rep(1L, nrow(df))
      granularity <- "month"
    }
  } else if (has(quarter_col)) {
    q <- parse_quarter(df[[quarter_col]])
    month <- (q - 1L) * 3L + 1L
    day <- rep(1L, nrow(df))
    granularity <- "quarter"
  } else {
    month <- rep(1L, nrow(df))
    day <- rep(1L, nrow(df))
    granularity <- "year"
  }

  bad <- is.na(year) | is.na(month) | is.na(day) |
    month < 1 | month > 12 | day < 1 | day > 31
  ds <- rep(as.Date(NA), length(year))
  ok <- !bad
  ds[ok] <- suppressWarnings(as.Date(sprintf("%04d-%02d-%02d", year[ok], month[ok], day[ok])))

  if (all(is.na(ds))) {
    stop("Could not build any valid dates from the selected columns. ",
         "Check that Year is numeric and Quarter/Month values are recognizable.",
         call. = FALSE)
  }

  list(ds = ds, granularity = granularity)
}
