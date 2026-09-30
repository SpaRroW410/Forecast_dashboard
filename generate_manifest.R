# Generates manifest.json for Posit Connect Cloud, which requires it for any
# Shiny-for-R deployment from GitHub (it tells Connect Cloud which R version
# and which package versions to install). Run this from an R session that
# already has the app's real dependencies installed (i.e. app.R's
# pacman::p_load(...) list succeeds in this session) -- writeManifest()
# serializes the ACTUAL installed package versions/sources/checksums, so it
# can't be run correctly anywhere else. .rscignore excludes forecastsuite/
# (a separate package, not part of this app) from the dependency scan.
#
# repos points at a Posit Package Manager BINARY url rather than the default
# source-only cran.rstudio.com, so each package's manifest entry records a
# repository Connect Cloud can pull a precompiled binary from. Without this,
# prophet's manifest entry pointed at a source-only mirror, so Connect Cloud
# had to compile prophet's bundled Stan model (rstan/StanHeaders) from
# scratch at deploy time -- slow enough that it tripped Connect Cloud's
# worker-startup timeout and the deploy failed with "Unable to connect to
# worker after 60.00 seconds; startup took too long" before R ever started.
#
# NOTE: the generic .../cran/latest alias serves SOURCE packages, not
# binaries -- that was tried first and still compiled prophet from scratch.
# P3M's Linux binaries require the explicit
# .../cran/latest/bin/linux/<distro>-<arch>/<r-major.minor> form (it doesn't
# depend on the requesting client's HTTPUserAgent being set correctly, unlike
# the older .../cran/__linux__/<distro>/latest form). Connect Cloud's own
# platform isn't directly inspectable from here, but shinyapps.io (Connect
# Cloud's closest sibling product) is still reporting Ubuntu 22.04 (jammy)
# x86_64 in its own R-version-support errors as of R 4.6.x, so that's what's
# used below. If P3M hasn't yet built jammy/R-4.6 binaries for this exact
# dependency chain (StanHeaders/rstan/prophet are large, slow-to-rebuild
# packages and R 4.6.1 is very recent), this alone won't fix the timeout --
# the next lever would be regenerating this manifest from an R 4.5.x install
# instead, which has longer-established binary coverage.
options(repos = c(CRAN = "https://packagemanager.posit.co/cran/latest/bin/linux/jammy-x86_64/4.6"))

# Usage:
#   Rscript generate_manifest.R
# Re-run and commit the updated manifest.json whenever app.R's package list
# changes -- a stale manifest is a common cause of Connect Cloud deploy
# failures.

if (!requireNamespace("rsconnect", quietly = TRUE)) install.packages("rsconnect")

rsconnect::writeManifest(appDir = ".")
