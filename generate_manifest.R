# Generates manifest.json for Posit Connect Cloud, which requires it for any
# Shiny-for-R deployment from GitHub (it tells Connect Cloud which R version
# and which package versions to install). Run this from an R session that
# already has the app's real dependencies installed (i.e. app.R's
# pacman::p_load(...) list succeeds in this session) -- writeManifest()
# serializes the ACTUAL installed package versions/sources/checksums, so it
# can't be run correctly anywhere else. .rscignore excludes forecastsuite/
# (a separate package, not part of this app) from the dependency scan.
#
# Usage:
#   Rscript generate_manifest.R
# Re-run and commit the updated manifest.json whenever app.R's package list
# changes -- a stale manifest is a common cause of Connect Cloud deploy
# failures.

if (!requireNamespace("rsconnect", quietly = TRUE)) install.packages("rsconnect")

rsconnect::writeManifest(appDir = ".")
