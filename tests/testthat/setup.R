# Shared setup for the hosted-app tests. The working directory is
# tests/testthat/ while these run.
app_dir <- normalizePath(file.path("..", ".."))

suppressPackageStartupMessages({
  library(dplyr); library(lubridate); library(tibble); library(stringr); library(tidyr)
})
for (f in list.files(file.path(app_dir, "helpers"), pattern = "\\.R$", full.names = TRUE)) {
  source(f, local = TRUE)
}

demo_series <- function() {
  raw <- utils::read.csv(file.path(app_dir, "data", "daily-total-female-births.csv"))
  process_uploaded_data(raw, "agg", "Date", "Births", date_agg = "day")
}

# Fit quietly: prophet/rstan are chatty.
quiet <- function(expr) {
  out <- NULL
  utils::capture.output(out <- suppressWarnings(suppressMessages(expr)))
  out
}

# chromote can't use Chrome's sandbox when running as root (containers, some CI).
if (requireNamespace("chromote", quietly = TRUE) && .Platform$OS.type == "unix" &&
    identical(unname(Sys.info()[["user"]]), "root")) {
  chromote::set_chrome_args(c(chromote::default_chrome_args(), "--no-sandbox"))
}
