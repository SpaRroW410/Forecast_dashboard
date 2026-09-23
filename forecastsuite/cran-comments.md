# cran-comments

## Submission type

This is a new submission.

## Test environments

<!-- Fill in after running R CMD check --as-cran locally / on win-builder / -->
<!-- on r-hub, e.g.: -->
<!-- * local: R 4.x.y on <platform> -->
<!-- * win-builder (devel and release) -->
<!-- * R-hub: ubuntu-latest (release), windows-latest (release), macos-latest (release) -->

## R CMD check results

<!-- Paste the actual `R CMD check --as-cran` output summary here once it's -->
<!-- been run (0 errors | 0 warnings | 0 notes, or explain any NOTE). -->

## Downstream dependencies

There are currently no downstream dependencies for this package (new submission).

## Notes for reviewers

* `torch` and `prophet` are both optional (Suggests, not Imports), each used only for
  its own model (LSTM, Prophet respectively) and always behind
  `requireNamespace(..., quietly = TRUE)` -- every example, test, and vignette chunk
  that touches either is skipped when the package isn't installed. `prophet` pulls in a
  compiled Stan backend (`rstan`/`StanHeaders`) with a documented history of install/
  check fragility on some platforms; keeping it Suggests-only means a check environment
  without a working Stan toolchain still installs and checks forecastsuite cleanly.
* No test or vignette makes a live network call; the one Google Sheets-related test
  only exercises the pure URL-building helper (`googlesheet_csv_url()`).
* `run_app()` is interactive (launches a Shiny app); its example is guarded with
  `if (interactive())` rather than actually launching the app during checks.
