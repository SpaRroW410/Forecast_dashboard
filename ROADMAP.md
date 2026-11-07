# Repository Roadmap — Forecast Dashboard (hosted app)

This roadmap covers the **repository and the hosted Shiny app**: deployment, reliability, UX, testing,
CI and documentation. It deliberately leaves out new forecasting features and changes to the
`forecastsuite` package's internals. Those belong in `forecastsuite/ROADMAP.md`. It supersedes
[`ROADMAP_v0.7.md`](ROADMAP_v0.7.md) as the statement of this repository's priorities.

The evidence for every item is in
[`docs/audit/2026-11-03-deployment-ui-audit.md`](docs/audit/2026-11-03-deployment-ui-audit.md).
The finding IDs (H1, F2, …) refer to that report.

Guiding rules:

- Package code is stable and protected. A package change needs a confirmed defect, plus evidence that
  a repository-level fix can't solve it.
- A working Posit Connect Cloud deployment comes before refactoring.
- Never hand-edit generated files (`manifest.json`, `renv.lock`).

---

## Immediate (High Priority)

### Deployment stability / Posit Connect Cloud reliability
- [x] **Regenerate `manifest.json` on Linux in CI** — done: `.github/workflows/hosted-app.yaml` + `generate_manifest.R` (snapshot 2026-11-03, verified; see README)., not on a Windows workstation and not by hand.
      Use R 4.5.x (inside Connect Cloud's documented 4.0.0–4.6.0 range) and one dated Posit Package
      Manager snapshot, so every pinned version exists in that snapshot's index. Replaces the current
      hand-patched manifest: R 4.6.1, 31 versions only available as source, 18 unused packages
      including `torch`.
- [x] **Bundle hygiene** — done. `.rscignore` rewritten in rsconnect's exact-name syntax (the old gitignore-style lines never matched anything); bundle down to the app's 26 files. add `forecastsuite.Rcheck/`, `*.tar.gz`, `generate_manifest.R`,
      `generate_renv_lock.R` and `docs/` to `.rscignore`. Stop tracking `forecastsuite.Rcheck/`,
      `forecastsuite_1.0.1.tar.gz`, `.Rproj.user/` and `.Rhistory` (they are already in `.gitignore`
      but were committed earlier).
- [ ] *(Needs Connect Cloud access — documented in README, not yet configured.)* **Deploy from a `deploy` branch or tag**, promoted only after CI is green, so a bad manifest can't
      take the live app down. Roll back by reverting one commit.
- [ ] *(Blocked: no current Connect Cloud connection.)* **Collect the current Connect Cloud build/runtime log** and attach it to the deploy runbook.
      It's the one input the audit couldn't access.

### Error handling (runtime defects seen by users)
- [x] *(done)* Fix the **Holidays session crash** (H1/H2): `ignoreInit = TRUE` plus `req(isTRUE(...))` on the
      finalize observer, and NULL guards on `holiday_windows()` and `compiled_holidays()`.
- [x] *(done)* Replace `library(pacman); p_load(...)` with plain `library()` calls, so a missing package fails
      clearly instead of installing at start-up.
- [x] *(done)* Add a guarded UTF-8 locale line at the top of `app.R` (G1) so emoji labels never render as
      `<f0><9f>…` bytes.
- [x] *(done)* Show a clear message when the hold-out window is ≥ the data length (F2). The bundled demo data
      currently fails with default settings.
- [x] *(done, owner-approved)* fix the Prophet horizon/frequency mismatch in `helpers/modeling_functions.R`
      (F1: a 24-month request currently forecasts 13.8 years). It's app-level code, but it changes
      forecast output.

---

## Next Release

### Shiny UX refinement
- [x] *(done)* Holidays clean-up batch (H3–H19): sign hint and `max = 0` on the lower window, one import heading
      instead of six, distinct verbs instead of four kinds of "Finalize", an action button instead of the
      finalize checkbox, `sep = ""` on the year slider, help text explaining when manual entries are
      included, shorter sub-tab labels.
- [x] *(done)* Data Import (D1–D7): fix the 30 MB note overlapping the button, captions for the import-method
      icons, remove or qualify *Hourly*, rename *Aggregation Frequency*.
- [x] *(done, except F7 silent buttons: see Error handling)* Forecast / ARIMA / SARIMA (F3–F7, A1–A4): hold-out control placed above *Generate Forecast* and
      named consistently, readable axis labels and dates, a "no seasonal terms found" note on SARIMA.
- [x] *(done; Model Guide demo uncertainty toggle M1/M2 fixed too)* Global: remove duplicate `📥` icons from download buttons, one product name and version (G3),
      update the "free ~1GB Shiny Server" wording (G4).
- [x] *(done)* Remove `shinyBS` (Bootstrap 3 only; raises a JS error on every page under bslib/Bootstrap 5).
- [x] *(done)* Remove the inline tab-fade CSS that forces every hidden tab to render eagerly (G2).

### Error handling
- [x] *(done)* Replace silent `req()` no-ops on buttons (Evaluate, Plotly, Fit) with `validate()` messages or
      notifications.
- [x] *(done)* Wrap the ARIMA and SARIMA fits in `tryCatch()` with user-facing notifications, as the Prophet
      path already does.

### Logging and diagnostics
- [x] *(done: `helpers/app_feedback.R`)* Log one line per key step to stderr, which Connect Cloud captures: session start, dataset
      rows/date range, model fit start/end with duration, caught errors.
- [x] *(done)* At start-up, log R version, locale and the versions of shiny/prophet/rstan/StanHeaders, so
      version skew shows up in the deployment log.

### Automated testing
- [ ] `testthat` tests for `helpers/` *(forecast length/step done in `tests/testthat/test-forecast-horizon.R`; rest open)*: forecast length and step, holiday-window sign, empty-holiday path,
      test-window ≥ data length, hourly aggregation.
- [x] *(done: `tests/testthat/test-app-smoke.R`)* A `shinytest2` (or Playwright) **smoke test** of the full demo flow: import → process → holidays
      (including *Apply Window Settings*) → forecast → ARIMA → SARIMA. It fails on any disconnect or page
      error.

### CI/CD
- [x] *(done, as the test job of `hosted-app.yaml`)* New workflow `app-check.yaml`, triggered on changes to `app.R`, `helpers/`, `server/`, `ui/`,
      `module/`, `www/`: install deps from P3M, run helper tests and the smoke test.
- [x] *(done, as the manifest job of `hosted-app.yaml`: regenerates after green tests and commits)* New workflow `deploy-manifest.yaml`.

---

## Medium-Term

### Dependency management
- [ ] Trim app dependencies to what the code uses. Decide the pending plotly question (opt-in toggle
      vs. removal) from `ROADMAP_v0.7.md`.
- [ ] Use `renv` for local/CI parity only; keep `manifest.json` as Connect Cloud's single source of truth.
- [ ] Scheduled monthly CI run: regenerate the manifest against a fresh snapshot, run the smoke test,
      and report drift before it reaches a deploy.
- [ ] Add a CI check, or a documented list, for divergence between `helpers/*.R` and their
      `forecastsuite/R/*` counterparts. The Prophet defect already exists in both copies.

### Documentation
- [ ] A deploy runbook in README: how the manifest is produced, how to promote and roll back, how to
      read the Connect Cloud logs, the known failure signatures and their fixes.
- [ ] Merge `UPDATE_LOG_v0.6.md` and the versioned roadmap into one `NEWS.md` and this file; align
      version numbers across README, footer and title.
- [ ] `CONTRIBUTING.md`: the "package is protected" rule, how to run tests and the smoke test locally,
      line-ending policy (`.gitattributes` with `* text=auto`), so Windows checkouts stop producing
      CRLF-skewed manifests.

### User onboarding
- [ ] A **Load demo data** button on the Data tab (bundled CSV, sensible defaults), so first-time users
      reach a working forecast in one click.
- [ ] A short "how holidays flow" diagram or help panel on the Holidays tab (import → build list →
      windows → use for forecasting).
- [ ] An About/Diagnostics panel showing app version, git SHA, R and key package versions.

---

## Long-Term

- [ ] Re-evaluate whether the hosted app should depend on a CRAN release of `forecastsuite` instead of
      copied helpers. Do this only if it reduces maintenance without adding deploy risk; it's not a
      reason to change the package.
- [ ] Namespace Holiday/Forecast UI inputs inside proper Shiny modules. Inputs are currently global IDs
      shared across tabs, which causes hidden cross-tab dependencies.
- [ ] Load test with `shinyloadtest` to size the Connect Cloud tier and set per-session memory
      expectations.
- [ ] Accessibility pass: labelled icon buttons, colour contrast of the sepia theme, keyboard navigation
      of the import panel.

---

## Deferred / out of scope for this repository roadmap

These items from `ROADMAP_v0.7.md` are feature or forecasting-engine work. They should be reconsidered
only after the Immediate and Next Release items are done:
manual/hybrid changepoints, auto-highlighting the best prior, custom evaluation windows,
`data.table`/`arrow` migration, time-zone adjustment for hourly data, smarter frequency detection,
standalone binaries. Package-specific items stay in `forecastsuite/ROADMAP.md`.
