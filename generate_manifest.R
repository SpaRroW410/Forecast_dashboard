# Generates manifest.json for Posit Connect Cloud, which reads it to decide the
# R version and the exact package versions to install for this app.
#
# CANONICAL USE: the "Hosted app CI" GitHub Actions workflow
# (.github/workflows/hosted-app.yaml) runs this on Linux after the app's
# tests pass and commits the result. Don't hand-edit manifest.json, and
# avoid regenerating it on Windows/macOS: the manifest records the R version
# and package versions of the machine that writes it.
#
# Usage:
#   Rscript generate_manifest.R            # verify-only: fail if the library doesn't match the snapshot
#   Rscript generate_manifest.R --install  # first install/update the app's packages from the snapshot (CI)
#
# Why a dated Posit Package Manager snapshot
# ------------------------------------------
# The previous manifest was written on Windows from a library whose versions
# matched no single repository state, then hand-patched. 31 of its pinned
# versions were no longer "current" in the repository it pointed at, so the
# host could only fetch them as SOURCE tarballs from the CRAN archive and
# compile them (StanHeaders, RcppArmadillo, RcppParallel, data.table, ...) --
# slow enough to fail a deployment. Pinning every package to ONE snapshot date
# makes every recorded version an exact entry in that snapshot's index, so the
# host can install binaries. Packages are installed here from the snapshot's
# Linux-binary URL (__linux__/<distro>/<date>) for speed; rsconnect records
# the snapshot's canonical, distro-neutral URL (cran/<date>) in the manifest,
# and a Package Manager-aware host resolves that to binaries for its own
# Linux distribution.
#
# NOTE on .rscignore: rsconnect matches EXACT file/directory names, one per
# line, per directory -- no globs, no trailing "/", no comments. A
# gitignore-style "forecastsuite/" line silently matches nothing.
#
# To move to newer packages: change P3M_SNAPSHOT (a date, YYYY-MM-DD) here or
# in the workflow, push, and let CI regenerate and smoke-test.

snapshot <- Sys.getenv("P3M_SNAPSHOT", "2026-11-03")
distro   <- Sys.getenv("P3M_DISTRO", "noble")
repo     <- sprintf("https://packagemanager.posit.co/cran/__linux__/%s/%s", distro, snapshot)
options(repos = c(CRAN = repo))
if (.Platform$OS.type == "unix" && Sys.info()[["sysname"]] == "Linux") {
  # P3M serves Linux binaries only to clients that identify their R version/platform.
  options(HTTPUserAgent = sprintf("R/%s R (%s)", getRversion(),
    paste(getRversion(), R.version$platform, R.version$arch, R.version$os)))
}

# Connect Cloud documents support for R 4.0.0 through 4.6.0.
if (getRversion() < "4.0.0" || getRversion() > "4.6.0") {
  stop("R ", getRversion(), " is outside Connect Cloud's documented range (4.0.0-4.6.0). ",
       "Regenerate with a supported R version (CI uses R 4.5).", call. = FALSE)
}

# The app's direct dependencies are exactly its library() calls in app.R.
app_src  <- readLines("app.R", warn = FALSE)
app_pkgs <- unique(sub(".*library\\(([A-Za-z0-9.]+)\\).*", "\\1",
                       grep("^\\s*library\\([A-Za-z0-9.]+\\)", app_src, value = TRUE)))
if (length(app_pkgs) == 0) stop("No library() calls found in app.R.", call. = FALSE)
message("App packages (from app.R): ", paste(app_pkgs, collapse = ", "))

if ("--install" %in% commandArgs(trailingOnly = TRUE)) {
  # Install anything missing, then bring every installed package that differs
  # from the snapshot (including R's bundled recommended packages such as MASS
  # or lattice) to the snapshot's version.
  missing <- setdiff(c(app_pkgs, "rsconnect"), rownames(installed.packages()))
  if (length(missing)) install.packages(missing)
  outdated <- old.packages()
  if (!is.null(outdated)) install.packages(rownames(outdated))
}

if (!requireNamespace("rsconnect", quietly = TRUE)) {
  stop("rsconnect is not installed; run with --install or install.packages('rsconnect').", call. = FALSE)
}

# .rscignore keeps forecastsuite/, its build outputs, tests/, docs/ and these
# generator scripts out of both the bundle and the dependency scan.
rsconnect::writeManifest(appDir = ".")

# ---- Verify: refuse a manifest the host can't satisfy from the snapshot ----
manifest <- jsonlite::read_json("manifest.json")
index    <- read.dcf(url(paste0(repo, "/src/contrib/PACKAGES")), fields = c("Package", "Version"))
current  <- setNames(index[, "Version"], index[, "Package"])
pinned   <- vapply(manifest$packages, function(p) p$description$Version, character(1))
bad      <- pinned[is.na(current[names(pinned)]) | current[names(pinned)] != pinned]
if (length(bad)) {
  unlink("manifest.json")
  stop("manifest.json NOT written: these versions are not current in snapshot ", snapshot, ":\n  ",
       paste(sprintf("%s %s (snapshot: %s)", names(bad), bad, current[names(bad)]), collapse = "\n  "),
       "\nRe-run with --install so the library matches the snapshot.", call. = FALSE)
}
unexpected <- intersect(names(pinned), c("rsconnect", "renv", "testthat", "shinytest2", "torch", "forecastsuite"))
if (length(unexpected)) {
  unlink("manifest.json")
  stop("manifest.json NOT written: tooling/package-only dependencies leaked into the app: ",
       paste(unexpected, collapse = ", "), ". Check .rscignore.", call. = FALSE)
}
message(sprintf("manifest.json OK: R %s, %d packages, %d files, all pinned to %s",
                manifest$platform, length(pinned), length(manifest$files), repo))
