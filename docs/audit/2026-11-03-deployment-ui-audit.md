# Forecast Dashboard — Package, UI and Posit Connect Cloud Audit

**Date:** 2026-11-03 · **Repository commit audited:** `bf92544` (main) · **Package audited:** `forecastsuite` 1.0.3 (unmodified)

No package code was changed during this audit. No app code was changed either: every fix below is a
*recommendation*, ranked by risk, for the owner to approve.

## How this was tested

| Item | Detail |
|---|---|
| Platform | Ubuntu 24.04, R 4.3.3 (Ubuntu's R; R 4.6 could not be installed in the audit sandbox), packages from Posit Package Manager `noble/latest` binaries |
| Package | `R CMD build` + `R CMD check --as-cran --no-manual` on the built tarball; registry API called directly |
| Hosted app | `shiny::runApp(".")`, then a scripted Playwright browser walk-through of every tab using the bundled demo data (`data/daily-total-female-births.csv`, `data/example_holidays.csv`) |
| Workflow | The hosted app's own `helpers/` functions called exactly as `server/` calls them |
| Deployment | `manifest.json` cross-checked against Posit Package Manager indexes and HTTP headers; `rsconnect::writeManifest()` run on a clean `git archive` of the repo; Connect Cloud docs |

**Limitation:** I had no access to the Connect Cloud dashboard or its logs, so the deployment diagnosis
is built from the repository, package-repository evidence and local reproduction. The single most
useful next input is the **current Connect Cloud build/runtime log text**.

---

# Package Health

**Verdict: healthy. No package change is needed for deployment.**

| Check | Result |
|---|---|
| `R CMD build` | OK (9.5 s) → `forecastsuite_1.0.3.tar.gz` |
| `R CMD check --as-cran` | **0 ERRORs**, 2 WARNINGs, 2 NOTEs — **all environmental** (see below) |
| testthat | **713 pass, 0 fail**, 2 skip (intentional: "prophet is installed"), 46 warnings (non-failing) |
| Examples (incl. `--run-donttest`) | OK |
| Vignette re-build | OK |
| Install / namespace / unload | OK; "dependencies in R code … OK" |
| Registry API (`get_model("prophet")`, `get_model("arima")`) | Runs |

The WARNINGs and NOTEs came from the audit container, not the package: no `en_US.UTF-8` locale, no `qpdf`,
`torch` (Suggests) not installed, and "unable to verify current time" (no network clock). The 46 test
warnings cluster in data-edge-case tests (`test-grouping-pipeline.R`, `test-rolling-cv.R`,
`test-population-incidence.R`, `test-individual-observations.R`, …). They are worth triaging later but are
not defects.

**One confirmed functional defect, shared with the hosted app** (see *Changes That May Eventually Require
Package Changes*): with default settings, the Prophet adapter (`R/model_prophet.R:93`) forecasts in
**weekly** steps while the horizon is counted in **days**. A 24-month daily request returns 720 weekly rows
ending **13.8 years** after the training data.

**Structural note.** The hosted app (`app.R`) does **not** use `forecastsuite`. It `source()`s its own
copies of the helpers in `helpers/`. The package therefore cannot be the cause of a Connect Cloud failure.
The cost of this split is that the two copies can drift apart, and the Prophet defect is already present
in both.

Not exercised: the LSTM/`torch` path; `forecastsuite::run_app()` in a live browser (its server logic is
covered by the package's own `testServer` tests); R 4.6.x.

---

# Shiny UI Findings

Severity: **Critical** (crash or wrong output), **High** (blocks or misleads the main workflow), **Medium**
(confusing, or a visual defect), **Low** (polish). The screenshots are in the audit session's scratchpad,
not in this repository. Each is described in words below.

## Holidays section (where issues were already reported)

| # | Location | Severity | What you see | Suggested fix |
|---|---|---|---|---|
| H1 | Holidays → 2️⃣ → **📌 Apply Window Settings** (`server/server_holidays.R:219-229`, root cause `:256`) | **Critical** | After data is processed, selecting a holiday label and clicking *Apply Window Settings* **disconnects the session** (grey "disconnected" overlay). Server log: `Error in UseMethod: no applicable method for 'filter' applied to an object of class "NULL"`. Reproduced every time. | Root cause: `observeEvent(input$confirm_finalize, …)` fires at module start-up because the checkbox value is `FALSE`, not `NULL`. It sets `holiday_windows(NULL)`, `compiled_holidays(NULL)`, and so on. Fix: add `ignoreInit = TRUE` and `req(isTRUE(input$confirm_finalize))`. Also guard `holiday_windows() %||% <empty tibble>`. This is a server-side guard in the app, not forecasting logic. |
| H2 | Data Import → **📦 Process & Save** | High | The toast "✅ Final holiday list finalized." appears on the **Data** tab before the user has opened Holidays. It appears again on every re-process. | Same fix as H1. |
| H3 | 2️⃣ → "Lower Window (days before)" | High | The label invites a positive number. Entering `2` makes the forecast fail with Prophet's `Holiday lower_window should be <= 0`. | Change the label to "Days before holiday (0 or negative, e.g. -2)". Use `numericInput(..., max = 0)` here and `min = 0` on the upper window. |
| H4 | 1️⃣ import block | Medium | Six stacked "import" labels: button **Import Movable Holidays** → heading **Choose Import Method** (an unstyled h3, bigger than the tab's own headings) → datamods tabs **Import / View / Update** → **Import a file** → **Upload a file:** → button **Import data**. After all that, **🧩 Finalize Movable Holidays** is still needed. This is the main source of the duplicated and overlapping wording that was reported. | Remove the module's `h3("Choose Import Method")` or make it a small caption. Rename the button to "Add holidays from a file…". Rename *Finalize Movable Holidays* to "Add these to the holiday list". |
| H5 | 1️⃣ and 4️⃣ download buttons (also in Data, Forecast, ARIMA and SARIMA) | Medium | Two icons on each button: `⬇ 📥 Download …`. `downloadButton()` already adds an icon. | Remove the `📥` emoji from every `downloadButton` label. |
| H6 | 1️⃣ "Shows the expected format: a date column and a label column." | Medium | The help text sits inline, squeezed between two buttons. It wraps and collides with them at narrower widths. | Wrap the button and help text in a `div()`, or move the help text below the button. |
| H7 | 1️⃣ "Fixed Holiday Year Range" slider | Medium | Years show thousands separators: **2,015 – 2,025**. | Add `sliderInput(..., sep = "")`. |
| H8 | 1️⃣ year-range default (2015–2025) | Medium | Unrelated to the data's dates. With the demo data (1959), every generated holiday falls outside the data, so the Contingency tables are empty with no explanation. | Add help text: "Pick years that cover your data". A follow-up could default the range to the dataset's years (a small server change). |
| H9 | Whole app | Medium | "Finalize" means four different things: *Finalize Movable Holidays* (append), *Finalize Holiday List* (destructive lock and wipe), Data step *3️⃣ Finalize*, *Finalize Population Data*. | Use distinct verbs: "Add to list", "Use these holidays for forecasting", "Review & process", "Confirm population data". |
| H10 | 4️⃣ "✅ Finalize Holiday List" | Medium | A **checkbox** carries an action, with a ✅ emoji next to the tick box (two checkmarks). After ticking it, the page shows `[1] "Total holidays: "` (blank count), an empty table, and "No holiday entries found." It looks as if the holidays were lost. | Use an `actionButton("Use these holidays for forecasting")`. After it runs, show the final list's count instead of the wiped working copy. |
| H11 | 4️⃣ summaries | Low | R print artefacts: `[1] "Total holidays: 123"`, `[1] "Select a row …"`. | Use `renderText`/`textOutput` instead of `renderPrint`/`verbatimTextOutput`. |
| H12 | 4️⃣ "📊 Summary of Holiday Types" | Low | The table actually counts rows per holiday **label**, not per type. | Rename it "Holiday counts by name". |
| H13 | 2️⃣ manual entries | Medium | Manual holidays only reach the combined list when **🧮 Generate Holidays** on 1️⃣ is clicked, and that button is hidden when "Enable Holiday Effects" is *No*. Its toast and modal mention only "Sundays and fixed holidays". | Rename the button "Build holiday list (Sundays + fixed + manual)". Add help text on 2️⃣ saying when manual entries are included. Update the modal text. |
| H14 | 2️⃣ "Fixed (recurring every year)" | Low | Expands across the year range set on the 1️⃣ slider (a hidden dependency). The date defaults to today. | Help text: "Repeats for every year in the range set on step 1". |
| H15 | 3️⃣ Contingency | Low | The same idea is stated three times: heading "Holiday Contingency Analysis", radio "Show Contingency Analysis:", and help text. | Use one checkbox: "Check holidays against my data". Show a message when both tables are empty. |
| H16 | 1️⃣ "Enable Holiday Effects: No" | Low | It doesn't disable anything. It only hides step-1 controls, and steps 2–4 keep working. | Relabel it "Configure holidays?", or also hide steps 2–4. |
| H17 | 1️⃣ column pickers, all tables | Low | Prophet jargon: "Date Column (ds):", "Label Column (holiday):", `ds`/`y` headers. | Use "Date column", "Holiday name column", and `colnames=` in `datatable()`. |
| H18 | 1️⃣ import button tooltip | Low | The browser console shows `No method named "destroy"` on every page. `shinyBS::bsTooltip` is Bootstrap 3 only, while the app uses bslib Bootstrap 5, so the "Upload Dataset" tooltip (also the wrong wording here) never works. | Replace it with a `title=` attribute or `bslib::tooltip()` and drop `shinyBS`. |
| H19 | Holiday sub-tab labels | Low | Long labels with keycap emoji wrap onto a second row on a 1400 px screen. | Shorten them: "1 · Import & fixed", "2 · Manual & windows", "3 · Check", "4 · Review & use". |

## Global

| # | Location | Severity | What you see | Suggested fix |
|---|---|---|---|---|
| G1 | Every `source()`d UI file | **High (conditional)** | In a non-UTF-8 locale (here: POSIX), **every emoji renders as raw bytes**: tabs read `<f0><9f><93><98> Model Guide` and `1<ef><b8><8f><e2><83><a3> Main Data`. `app.R`'s own emoji render fine because Shiny reads `app.R` as UTF-8. `manifest.json` records locale `en_IN`, which is unlikely to exist on a hosting image. On Connect Cloud this would look exactly like "duplicated, overlapping wording". | Tested fix: at the top of `app.R`, `if (!l10n_info()[["UTF-8"]]) Sys.setlocale("LC_CTYPE", "C.UTF-8")`. Note that `source(encoding = "UTF-8")` makes things **worse** in a POSIX locale (parse error), so don't use it. |
| G2 | Inline CSS in `app.R` (tab fade) | Medium (performance) | Inactive tab panes are forced to `display:block !important`, so Shiny treats them as visible and **renders every tab eagerly**. Verified: the ARIMA and SARIMA tables had rendered while the user was still on the Data tab. This works against the app's memory-saving design. | Delete that `<style>` block. Bootstrap 5 already fades tabs. |
| G3 | Title, loader, footer, README, Model Guide | Medium | Several names: "📈 Prophet Forecast Dashboard", "Loading Prophet Forecast Dashboard...", "Forecast Dashboard v0.7", "Prophet Forecasting Model Guide" (which also covers ARIMA/SARIMA), README "v0.7.0". | Use one name ("Forecast Dashboard") and one version source. |
| G4 | Model Guide → Other Models; App Guide → Want more? | Medium | Says the app targets "a free ~1GB-RAM Shiny Server tier". It is deployed on Posit Connect Cloud. | Update the wording. |
| G5 | Top-level tabs | Low | Only the two guide tabs have emoji. | Use emoji on all tabs or none. |

## Data Import & Settings

| # | Location | Severity | What you see | Suggested fix |
|---|---|---|---|---|
| D1 | 1️⃣ "File uploads are limited to 30MB." | Medium | **Overlaps** the bottom of the blue **Import data** button (inline `margin-top:-8px`). | Remove the negative margin and render it as `helpText()` below the button. |
| D2 | 1️⃣ heading stack | Medium | "📂 Upload Main Dataset" (h4) → button "Time Series" → **"Choose Import Method"** (larger h3, black) → "Import a file" → "Upload a file:". | Rename the button "Choose data source…" and drop the h3 (same fix as H4, since it's the same module). |
| D3 | Import-method icon row | Low | Icons have no visible labels (hover text only). "Environment" lists the **server's** R datasets and "Google Sheets" needs a public link, which is meaningless or unclear on a hosted app. | Add captions under the icons. Consider removing `env` from the hosted app's method list. |
| D4 | "Aggregation Frequency: Hourly" | Medium | Offered, but Prophet then fails with "Unsupported aggregation type for forecasting horizon." | Remove *Hourly*, or label it "Hourly (ARIMA/SARIMA only)". |
| D5 | "Aggregation Frequency" with *Aggregated Time Series* | Medium | It **does not aggregate**. Daily data with *Monthly* selected still yields 365 daily rows, which SARIMA then treats as monthly (frequency 12). | Label it "Data frequency (must match your rows)", or implement real aggregation (a logic change, owner decision). |
| D6 | Main panel "Population Dataset Preview" | Low | The heading shows even when population isn't used. | Wrap it in the same `conditionalPanel`. |
| D7 | 3️⃣ "📦 Process & Save Final Dataset" | Low | Nothing is saved. | Rename it "Process dataset". |

## Forecast & Evaluation

| # | Location | Severity | What you see | Suggested fix |
|---|---|---|---|---|
| F1 | Forecast plot (`helpers/modeling_functions.R:59-61`) | **Critical (logic, not changed)** | With defaults, a 24-month horizon draws a forecast that runs **to 1973 from 1959 data**: 720 weekly steps, 13.8 years. Hold-out metrics are computed on only **13 of 92** test days, because forecast dates are weekly. | Owner decision needed (forecasting logic). Minimal fix: use the dataset's own frequency for `make_future_dataframe()` (`freq = "day"` for daily data). See the package section below. |
| F2 | 🚀 Generate Forecast with the demo data | High | Default settings fail: "❌ Forecast failed: Dataframe has less than 2 non-NA rows." The 12-month default test window equals the whole 1-year demo dataset, so no training rows are left. | Show a clear message ("Test window (12 months) must be shorter than your data (12 months)"). Default the test window to 20 % of the data. |
| F3 | "🧪 Evaluation Settings → Manual Test Window" | Medium | It sits *below* Generate Forecast but changes the training split *used by* Generate Forecast. The metrics column calls it "Manual Entry". | Move it above the forecast button and call it "Hold-out test period (months)" in both places. |
| F4 | "Exclude Sundays in Forecasting" (Forecast) vs "Include Sundays as Holidays" (Holidays) | Medium | Two conflicting Sunday controls, both on by default. | Rename the first "Drop Sunday rows from training data" and cross-reference the two. |
| F5 | Colour picker "Trend Line" | Low | It also colours the forecast line. | Rename it "Forecast & trend line". |
| F6 | Forecast plot | Low | Axis labels are `ds`/`yhat`, the title is "Forecasted Incidence with Prophet" (domain-specific), and actuals aren't drawn. | `labs(x = "Date", y = "Value")` and the title "Prophet forecast". |
| F7 | 📋 Evaluation / 📈 Plotly buttons before a forecast exists | Low | Clicking does nothing (silent `req()`). | Show a notification: "Generate a forecast first". |

## ARIMA / SARIMA

| # | Location | Severity | What you see | Suggested fix |
|---|---|---|---|---|
| A1 | SARIMA plot title | Medium | "Forecasts from ARIMA(0,1,2)", identical to the ARIMA tab when no seasonal terms are found, so users think the tab is broken. | Add a line: "auto.arima found no seasonal terms for this series". |
| A2 | "Time Series with Missing Dates Filled" tables | Low | Dates render as `1959-01-01T00:00:00Z`. | Use `DT::formatDate()` or `format(ds, "%Y-%m-%d")`. |
| A3 | Plots | Low | X axis is an index ("Time" 1–4) and the Y axis is labelled `ts_data`. | Add `labs()`. |
| A4 | Horizon | Low | Silently taken from the Forecast tab's slider. | Say so in the yellow banner. |

## Model Guide / Application Guide

| # | Location | Severity | What you see | Suggested fix |
|---|---|---|---|---|
| M1 | Demo "Show Uncertainty Interval" | Medium | Unticking it doesn't hide the interval; it only hides the legend. | Remove the control, or relabel it. |
| M2 | Demo changepoint slider | Low | `min = 0.001, step = 0.01` produces values 0.001, 0.011…, so the default 0.05 snaps to 0.051. | Set `min = 0.01`. |
| AG1 | App Guide step 1 | Low | "pull a data frame from your R global environment" doesn't apply on the hosted app. | Remove it for the hosted app. |

---

# Posit Connect Cloud Findings

## Root-cause analysis

The app code itself starts fast. A local cold start reaches "Listening" in **~3 s**. Loading all 20
packages takes **2.4 s** (prophet 0.3 s) and the process sits at **229 MB** RSS. The previously reported
*"Unable to connect to worker after 60.00 seconds; startup took too long"* was therefore not caused by app
code. It points to package installation or environment problems. These are the causes, ranked by
likelihood and impact:

| Rank | Cause | Evidence | Level |
|---|---|---|---|
| **1** | **`manifest.json` is internally inconsistent** (built on Windows, then hand-patched twice) | • Records **R 4.6.1**; Connect Cloud documents support for **R 4.0.0–4.6.0**.<br>• **31 of 169** pinned versions are *not* in the `jammy-x86_64/4.6` "latest" binary index the manifest points to. P3M serves them only as **source** from Archive: `StanHeaders 2.32.10` returns `x-package-type: source`, while `2.39.1` returns `binary`. Source builds would include StanHeaders, RcppArmadillo, RcppParallel, data.table, curl and openssl, which is slow enough to exceed a start-up budget.<br>• **No single P3M snapshot matches** (2026-09-01: 12 mismatches; 09-10: 19; 09-22: 24), because the versions came from a Windows CRAN library plus R-bundled recommended packages.<br>• `rstan` resolves to a current binary while `StanHeaders` is pinned old. The package's own source comments name rstan/StanHeaders version skew as a crash source.<br>• **18 packages the app never uses**, including `torch`, `testthat`, `rsconnect`, `renv` and `snowflakeauth`. These are left over from an older scan that included `forecastsuite/`.<br>• All 29 file checksums are stale (CRLF and older content); locale `en_IN`.<br>• Hard-coded **jammy** binaries, but Connect Cloud's OS isn't documented. If it isn't jammy, compiled binaries may fail to load. | Repository |
| **2** | **Session crash in Holidays (H1)** | Reproduced deterministically: the grey "disconnected" screen appears on any host. Matches "displays errors". | Repository (app) |
| **3** | **Default demo flow errors (F2) and Prophet horizon (F1)** | The user sees "❌ Forecast failed…" on the bundled data with default settings, or an implausible 14-year forecast. | Repository (app) |
| **4** | **Locale mojibake (G1)** | Reproduced under POSIX. Depends on Connect Cloud's runtime locale (unknown). | Repository (app) |
| **5** | **`pacman::p_load()` at start-up** | `p_load` *installs* any missing package at run time. On a hosted runtime, a manifest gap then becomes a network install inside the start-up timeout instead of a clear "package not found" error. | Repository (app) |
| **6** | **Bundle hygiene** | Verified by running `rsconnect::writeManifest()` on a clean checkout. It bundles **all 164 files of `forecastsuite.Rcheck/` (13 MB)**, which is tracked in git and missing from `.rscignore`. It also pulls `rsconnect` and `renv` (with their dependency trees) into the *app's* dependencies via `generate_manifest.R` and `generate_renv_lock.R`. `forecastsuite_1.0.1.tar.gz` (stale; the package is now 1.0.3) is bundled too. | Repository |
| 7 | Eager rendering of hidden tabs (G2) | Verified. Raises memory use per session. | Repository (app) |
| 8 | `shinyBS` with Bootstrap 5 (H18) | JS error on every page load. Not fatal. | Repository (app) |

**Is anything package-level? No.** The deployed app doesn't load `forecastsuite`, and the manifest
correctly excludes it. Every deployment cause above is fixed in repository files.

## Solutions, ranked from lowest to highest risk

1. **Lowest risk, highest value: regenerate `manifest.json` on Linux in CI. Stop hand-patching it.**
   A GitHub Actions job on `ubuntu-latest` with **R 4.5.x** (inside the documented range) would set
   `options(repos = "https://packagemanager.posit.co/cran/<fixed date>")` and run
   `rsconnect::writeManifest()`. Using one dated snapshot makes every pinned version the *current*
   version in that snapshot's index, so nothing has to come from the source Archive. The job would
   commit the manifest or upload it as an artifact. Before the first run:
   - Add `forecastsuite.Rcheck/`, `*.tar.gz`, `generate_manifest.R`, `generate_renv_lock.R` and `docs/` to `.rscignore`.
   - `git rm -r --cached forecastsuite.Rcheck forecastsuite_1.0.1.tar.gz .Rproj.user .Rhistory`.

   Open question to settle with one test deploy: the distro-agnostic snapshot URL versus a
   `__linux__/<distro>` binary URL. That choice depends on Connect Cloud's OS, which Posit doesn't document.
2. **Low risk: small app-level runtime fixes.** Each is a few lines and none touches forecasting logic.
   Replace `library(pacman); p_load(...)` with plain `library()` calls. Add the guarded UTF-8 locale
   line (G1). Add `ignoreInit = TRUE` and NULL guards to the holiday observers (H1/H2). Show a clear
   message instead of the cryptic Prophet error when the test window ≥ the data (F2).
3. **Medium risk:** replace `manifest.json` with a CI-generated `renv.lock`. Connect Cloud now accepts
   it, and uses `manifest.json` if both exist. This works, but means changing two moving parts at once.
4. **Higher risk, don't:** further hand edits to `manifest.json`. Each previous hand patch fixed one
   symptom and left the file further from any real library.
5. **Highest risk, don't:** switch the hosted app to depend on `forecastsuite`. That adds a package
   install to every deploy and couples deploys to package releases.

## Safest deployment strategy

1. Deploy from a dedicated `deploy` branch (or a tag), not `main`, so a manifest mistake can't take the
   live app down.
2. Have a CI job regenerate the manifest on Linux, then run a headless **smoke test**. The Playwright
   walk-through used for this audit is a ready template: import demo data → process → holidays →
   forecast → ARIMA → SARIMA, failing on any page error or disconnect.
3. Promote to the live branch only when CI is green. Keep the previous manifest so a rollback is a
   one-commit revert.
4. After each deploy, check the Connect Cloud logs for source builds (`installing *source* package`) and
   start-up time.

---

# Repository Roadmap

See [`ROADMAP.md`](../../ROADMAP.md). It supersedes the feature-oriented `ROADMAP_v0.7.md` for this
repository's priorities.

---

# Changes Recommended Without Touching Package Code

Everything in the *Shiny UI Findings* and *Posit Connect Cloud Findings* sections. The highest-value items:

1. CI-generated `manifest.json` (R 4.5.x, Linux, dated P3M snapshot) plus an expanded `.rscignore` and untracked build outputs.
2. `pacman::p_load` → `library()`.
3. Guarded UTF-8 locale line in `app.R`.
4. Holiday observer guards (crash H1/H2).
5. Remove the tab-fade CSS (eager rendering).
6. UI text batch: H3–H19, D1–D7, F3–F7, A1–A4, M1–M2, AG1, G3–G5.
7. Remove `shinyBS`; remove duplicate download-button emoji; `sep = ""` on the year slider.
8. Owner decision: fix the Prophet horizon in `helpers/modeling_functions.R` (F1). This is app-level code, but it changes forecast output, so it needs approval under the "don't touch forecasting logic" rule.

---

# Changes That May Eventually Require Package Changes

## P1 — Prophet forecast horizon/frequency mismatch in `forecastsuite` (confirmed defect)

- **Where:** `forecastsuite/R/model_prophet.R:93`: `freq <- if (daily) "day" else if (weekly) "week" else "day"`.
- **Evidence:** calling `get_model("prophet")` with defaults on the package's bundled
  `daily-total-female-births.csv` (train to 1959-09-30) with `h = convert_months_to_horizon(24, "day")`
  (= 720) returned **720 rows at 7-day steps, ending 1973-07-18 (13.8 years)**. With weekly seasonality
  off, the same call ends 1961-09-19 (2.0 years), which is correct.
- **Reachability:** the package's own app defaults *Weekly Seasonality* to `TRUE` (`R/app_ui.R:230`). No
  package test asserts forecast length or step (713 tests pass while the defect exists).
- **Why a repository-level fix is not enough:** fixing `helpers/modeling_functions.R` corrects the
  **hosted** app only. Users of `forecastsuite::run_app()` and the exported registry API
  (`get_model("prophet")$forecast`) run the package's own copy, which nothing outside the package can
  correct.
- **Not needed for deployment.** Recommended handling: a 1.0.4 patch release with a one-line fix plus a
  regression test on forecast length and step. Until then, document it in `forecastsuite/NEWS.md`.

## Not recommended now

- Making the hosted app depend on `forecastsuite` to remove the duplicated helpers. It would reduce
  drift, but only after the package API is stable on CRAN, and it adds deploy risk (see solution 5).
- No other package change is supported by the evidence.
