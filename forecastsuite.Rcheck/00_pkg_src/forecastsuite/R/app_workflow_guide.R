# Application Guide tab: the end-to-end flow of producing a forecast, as
# opposed to the Model Guide's per-model/per-parameter reference. Same
# tags$details structure as build_guide_tab_ui() (R/app_guide.R) -- a flat
# sequence of steps rather than a nested tabsetPanel.

build_app_guide_tab_ui <- function() {
  shiny::fluidPage(
    shiny::h2("Application Guide"),
    shiny::p("The flow of making a forecast, start to finish. See the Model Guide tab for what each model/parameter/metric actually means."),
    shiny::tags$hr(),

    shiny::tags$details(
      open = TRUE,
      shiny::tags$summary("Step 1: Import your data (Import Data tab)"),
      shiny::tags$ul(
        shiny::tags$li("Pick a source: a file upload, a data frame already in your R session (or, like esquisse, a built-in dataset from any installed package), a Google Sheet, a CSV URL, pasted text, or the bundled demo dataset if you just want to explore."),
        shiny::tags$li("Pick your date and value columns (or the split Year/Quarter/Month/Day columns), the aggregation frequency, and -- optionally -- a grouping column to split the dataset into one series per distinct value."),
        shiny::tags$li("Click ", shiny::strong("Finalize Dataset"), ". The Recommended Model table below the preview is a free, no-fitting starting suggestion for the next step.")
      )
    ),

    shiny::tags$details(
      open = FALSE,
      shiny::tags$summary("Step 2: Configure holidays (Holidays tab, optional)"),
      shiny::tags$ul(
        shiny::tags$li("Skip this entirely if your data has no calendar-driven effects -- every model works without it."),
        shiny::tags$li("Otherwise compile Sundays, the fixed-date catalog, movable holidays from a file (download the example file on that tab first if you're unsure of the format), and manual one-off entries."),
        shiny::tags$li("Click ", shiny::strong("Finalize Holidays"), ". The consistency check further down can help catch dates that look like closures but were never declared.")
      )
    ),

    shiny::tags$details(
      open = FALSE,
      shiny::tags$summary("Step 3: Pick a model and fit (Model tab)"),
      shiny::tags$ul(
        shiny::tags$li("Choose a model, set its parameters (or use the recommendation table's suggested starting values), a forecast horizon, and a test window for evaluation."),
        shiny::tags$li("If grouping is on, pick which groups to fit this run before clicking ", shiny::strong("Fit & Forecast"), "."),
        shiny::tags$li("Optionally run ", shiny::strong("Compare Selected Models"), " or ", shiny::strong("Run Cross-Validation"), " for a more robust read than a single train/test split.")
      )
    ),

    shiny::tags$details(
      open = FALSE,
      shiny::tags$summary("Step 4: Read your results"),
      shiny::tags$ul(
        shiny::tags$li("The forecast plot and the metrics table (MASE / sMAPE / RMSE across several evaluation windows) are the core output -- both have one-click downloads."),
        shiny::tags$li("The Analysis panel (seasonal decomposition, anomaly detection, residual diagnostics, and, with grouping on, cross-group correlation) is optional deeper diagnostics, not required reading for a first forecast."),
        shiny::tags$li("\"Show Code\" prints the R that reproduces exactly what you just ran, if you want to take it outside the app.")
      )
    ),

    shiny::tags$details(
      open = FALSE,
      shiny::tags$summary("Step 5: Save your work (optional)"),
      shiny::p("\"Save Project (.rds)\", visible from any tab, saves your dataset(s), holidays, and every setting -- not the fitted models themselves (see the Model Guide's note on why). Reload it later with \"Load Project (.rds)\" and click Fit & Forecast again to pick up where you left off.")
    )
  )
}
