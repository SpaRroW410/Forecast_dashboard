# Generates manifest.json for Posit Connect Cloud, which requires it for any
# Shiny-for-R deployment from GitHub (it tells Connect Cloud which R version
# and which package versions to install). Run this from an R session that
# already has the app's real dependencies installed (i.e. app.R's
# pacman::p_load(...) list succeeds in this session) -- writeManifest()
# serializes the ACTUAL installed package versions/sources/checksums, so it
# can't be run correctly anywhere else. .rscignore excludes forecastsuite/
# (a separate package, not part of this app) from the dependency scan.
#
# repos points at Posit Package Manager's binary CRAN mirror rather than the
# default source-only cran.rstudio.com, so each package's manifest entry
# records a repository Connect Cloud can pull a precompiled binary from
# (P3M auto-detects the requesting machine's platform). Without this,
# prophet's manifest entry pointed at a source-only mirror, so Connect Cloud
# had to compile prophet's bundled Stan model (rstan/StanHeaders) from
# scratch at deploy time -- slow enough that it tripped Connect Cloud's
# worker-startup timeout and the deploy failed with "Unable to connect to
# worker after 60.00 seconds; startup took too long" before R ever started.
options(repos = c(CRAN = "https://packagemanager.posit.co/cran/latest"))

# Usage:
#   Rscript generate_manifest.R
# Re-run and commit the updated manifest.json whenever app.R's package list
# changes -- a stale manifest is a common cause of Connect Cloud deploy
# failures.

if (!requireNamespace("rsconnect", quietly = TRUE)) install.packages("rsconnect")

rsconnect::writeManifest(appDir = ".")
