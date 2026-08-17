# Google Sheets import without an auth flow or extra dependency.
#
# Any sheet shared as "Anyone with the link can view" exposes a CSV export
# endpoint, so a normal read.csv() is enough. That is deliberately
# preferred over googlesheets4: it needs no OAuth round-trip (awkward in a
# local Shiny app), no credential storage, and no extra package. The
# trade-off is that genuinely private sheets are not reachable -- those
# need to be link-shared first, which the UI says explicitly.
#
# Handles the URL shapes people actually paste:
#   .../spreadsheets/d/<ID>/edit#gid=123
#   .../spreadsheets/d/<ID>/edit?usp=sharing
#   .../spreadsheets/d/<ID>/view
#   .../spreadsheets/d/<ID>
# plus a bare <ID>.

extract_sheet_id <- function(url) {
  url <- trimws(url)
  if (!nzchar(url)) stop("Provide a Google Sheets URL.", call. = FALSE)

  m <- regmatches(url, regexpr("/spreadsheets/d/([A-Za-z0-9_-]+)", url))
  if (length(m) == 1 && nzchar(m)) {
    return(sub("/spreadsheets/d/", "", m))
  }
  # A bare ID: Google IDs are long and have no slashes or spaces.
  if (grepl("^[A-Za-z0-9_-]{20,}$", url)) return(url)

  stop("Could not find a spreadsheet ID in that URL. Paste the full ",
       "Google Sheets link, e.g. https://docs.google.com/spreadsheets/d/<id>/edit",
       call. = FALSE)
}

# gid identifies the worksheet tab. If the pasted URL carries one and the
# caller does not override it, reuse it so the user lands on the tab they
# were actually looking at.
extract_sheet_gid <- function(url) {
  url <- trimws(url)
  m <- regmatches(url, regexpr("[#&?]gid=([0-9]+)", url))
  if (length(m) == 1 && nzchar(m)) return(sub("^[#&?]gid=", "", m))
  NULL
}

googlesheet_csv_url <- function(url, gid = NULL) {
  id <- extract_sheet_id(url)
  if (is.null(gid) || !nzchar(as.character(gid))) gid <- extract_sheet_gid(url)
  base <- sprintf("https://docs.google.com/spreadsheets/d/%s/export?format=csv", id)
  if (!is.null(gid) && nzchar(as.character(gid))) {
    base <- paste0(base, "&gid=", gid)
  }
  base
}

read_google_sheet <- function(url, gid = NULL) {
  csv_url <- googlesheet_csv_url(url, gid)
  utils::read.csv(csv_url, check.names = FALSE)
}
