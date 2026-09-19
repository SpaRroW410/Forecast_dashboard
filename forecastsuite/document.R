# Regenerates NAMESPACE and man/*.Rd from this package's roxygen2 comments.
# Run this from an R session with roxygen2 installable (this sandbox
# can't: no CRAN access, confirmed earlier in this package's development --
# same reason generate_manifest.R/generate_renv_lock.R at the repo root
# can't be run here either).
#
# The hand-written NAMESPACE (see its own header comment) still exports
# everything correctly if this is never run -- roxygenise() just replaces
# it with an equivalent, auto-generated version plus real man/*.Rd pages
# for every @export'd function, which the hand-written NAMESPACE alone
# can't provide (needed for R CMD check and CRAN submission).
#
# Usage (from inside forecastsuite/):
#   Rscript document.R
# Re-run and commit the updated NAMESPACE/man/ whenever a function's
# roxygen comments or @export status change.

if (!requireNamespace("roxygen2", quietly = TRUE)) install.packages("roxygen2")

roxygen2::roxygenise()
