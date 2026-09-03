# Generates/updates renv.lock for this Shiny app, so its dependencies
# (currently: shiny, tibble, shinyjs, shinyBS, DT, bslib, datamods, dplyr,
# lubridate, ggplot2, prophet, plotly, shinycssloaders, tidyr, colourpicker,
# zoo, forecast, stringr, readxl -- see app.R's pacman::p_load(...)) are
# pinned to reproducible versions. Run this from an R session that already
# has those packages installed -- renv::snapshot() records the ACTUAL
# installed versions/sources/hashes, so it can't be run correctly anywhere
# else (same reason generate_manifest.R can't be run here either).
# .renvignore excludes forecastsuite/ (a separate package, not part of this
# app) from the dependency scan.
#
# Usage:
#   Rscript generate_renv_lock.R
# Re-run and commit the updated renv.lock whenever app.R's package list
# changes.

if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv")

# One-time project scaffolding (.Rprofile + renv/activate.R + renv/settings.json)
# -- only runs if renv hasn't been initialized here yet. bare = TRUE creates
# the infrastructure only; it does not touch the library or install anything.
if (!file.exists("renv/activate.R")) {
  renv::init(bare = TRUE)
}

renv::snapshot(prompt = FALSE)
