# Hosted-app tests (not the forecastsuite package's tests, which live in
# forecastsuite/tests/). Run from the repository root with:
#   Rscript -e 'testthat::test_dir("tests/testthat", stop_on_failure = TRUE)'
# CI: .github/workflows/hosted-app.yaml
testthat::test_dir("testthat", stop_on_failure = TRUE)
