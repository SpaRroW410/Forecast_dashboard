# Bundled local Shiny app UI. Three tabs mirroring the hosted app's
# workflow (import -> holidays -> model), collapsed into one unified
# "Model" tab that works across every registered model instead of having
# separate Forecast/ARIMA tabs like the hosted app does.

build_import_tab_ui <- function() {
  shiny::sidebarLayout(
    shiny::sidebarPanel(
      shiny::tags$strong("Import from"),
      icon_source_row(
        "fs_import_source",
        list(
          list(id = "fs_src_file",   value = "file",   icon = "folder-open", title = "File upload (CSV / TSV / Excel)"),
          list(id = "fs_src_env",    value = "env",     icon = "database",    title = "Global environment"),
          list(id = "fs_src_gsheet", value = "gsheet",  icon = "google",      title = "Google Sheet"),
          list(id = "fs_src_url",    value = "url",     icon = "link",        title = "URL"),
          list(id = "fs_src_paste",  value = "paste",   icon = "keyboard",    title = "Paste text"),
          list(id = "fs_src_demo",   value = "demo",    icon = "flask",       title = "Demo dataset (no data of your own needed)")
        )
      ),

      shiny::conditionalPanel(
        condition = "input.fs_import_source == 'file'",
        shiny::fileInput("fs_file", "Upload CSV / TSV / Excel",
                          accept = c(".csv", ".tsv", ".txt", ".xlsx", ".xls")),
        shiny::uiOutput("fs_sheet_ui")
      ),
      shiny::conditionalPanel(
        condition = "input.fs_import_source == 'env'",
        shiny::selectInput("fs_env_obj", "Data frame in global environment", choices = NULL),
        shiny::actionButton("fs_refresh_env", "Refresh list"),
        shiny::actionButton("fs_load_env", "Load", class = "btn-primary")
      ),
      shiny::conditionalPanel(
        condition = "input.fs_import_source == 'gsheet'",
        shiny::textInput("fs_gsheet_url", "Google Sheets link",
                          placeholder = "https://docs.google.com/spreadsheets/d/.../edit#gid=0"),
        shiny::textInput("fs_gsheet_gid", "Worksheet gid (optional)",
                          placeholder = "taken from the link if present"),
        shiny::p(style = "font-size:12px;color:#777;",
                 "The sheet must be shared as \"Anyone with the link can view\". No Google sign-in is needed."),
        shiny::actionButton("fs_load_gsheet", "Fetch", class = "btn-primary")
      ),
      shiny::conditionalPanel(
        condition = "input.fs_import_source == 'url'",
        shiny::textInput("fs_url", "CSV URL", placeholder = "https://.../data.csv"),
        shiny::actionButton("fs_load_url", "Fetch", class = "btn-primary")
      ),
      shiny::conditionalPanel(
        condition = "input.fs_import_source == 'paste'",
        shiny::textAreaInput("fs_paste", "Paste delimited text (with header)",
                              rows = 8, placeholder = "date,value\n2024-01-01,100"),
        shiny::radioButtons("fs_paste_sep", "Separator",
                             choices = c("Comma" = ",", "Tab" = "\t", "Semicolon" = ";"),
                             selected = ",", inline = TRUE),
        shiny::actionButton("fs_load_paste", "Load", class = "btn-primary")
      ),
      shiny::conditionalPanel(
        condition = "input.fs_import_source == 'demo'",
        shiny::p(style = "font-size:12px;color:#777;",
                 "5 years of simulated daily clinic visits (2019-2023): a trend, weekly and ",
                 "yearly seasonality, and missing/partially-open Sundays -- so you can explore ",
                 "aggregation, the recommendation, and the holiday consistency check with no ",
                 "data of your own."),
        shiny::actionButton("fs_load_demo", "Load Demo Dataset", class = "btn-primary")
      ),

      shiny::hr(),
      shiny::radioButtons(
        "fs_date_mode", "Date is stored as",
        choices = c("One date column" = "single",
                     "Separate Year / Quarter / Month / Day columns" = "parts"),
        selected = "single"
      ),

      shiny::conditionalPanel(
        condition = "input.fs_date_mode == 'single'",
        shiny::selectInput("fs_date_col", "Date Column", choices = NULL)
      ),
      shiny::conditionalPanel(
        condition = "input.fs_date_mode == 'parts'",
        shiny::selectInput("fs_year_col", "Year Column", choices = NULL),
        shiny::selectInput("fs_quarter_col", "Quarter Column (optional)", choices = NULL),
        shiny::selectInput("fs_month_col", "Month Column (optional)", choices = NULL),
        shiny::selectInput("fs_day_col", "Day Column (optional)", choices = NULL),
        shiny::p(style = "font-size:12px;color:#777;",
                 "Supply Quarter or Month, not both. Day needs Month. Aggregation is set automatically to the finest part you provide.")
      ),

      shiny::radioButtons(
        "fs_data_type", "Data Format",
        choices = c("Aggregated (one row per period, already a value)" = "agg",
                     "Individual Observations (one row per event -- counted for you)" = "individual"),
        selected = "agg"
      ),
      shiny::conditionalPanel(
        condition = "input.fs_data_type == 'agg'",
        shiny::selectInput("fs_value_col", "Value Column", choices = NULL)
      ),
      shiny::conditionalPanel(
        condition = "input.fs_data_type == 'individual'",
        shiny::p(style = "font-size:12px;color:#777;",
                 "Each row is one event (e.g. one case, one visit). No value column needed -- rows are counted per period.")
      ),
      shiny::radioButtons("fs_date_agg", "Aggregation Frequency",
                           choices = c("Hourly" = "hour", "Daily" = "day", "Weekly" = "week",
                                        "Monthly" = "month", "Quarterly" = "quarter", "Yearly" = "year"),
                           selected = "day"),
      shiny::conditionalPanel(
        condition = "input.fs_data_type == 'agg'",
        shiny::radioButtons(
          "fs_collapse_fun", "When several rows share a period",
          choices = c("Sum them (counts)" = "sum",
                       "Average them (rates)" = "mean",
                       "Median" = "median",
                       "Keep every row" = "none"),
          selected = "sum"
        )
      ),
      shiny::hr(),
      shiny::selectInput("fs_group_col", "Grouping Column (optional)", choices = c("(none)" = "")),
      shiny::conditionalPanel(
        condition = "input.fs_group_col != ''",
        shiny::p(style = "font-size:12px;color:#777;",
                 "Splits the finalized dataset into one time series per distinct value ",
                 "instead of collapsing everything into a single aggregate series."),
        shiny::tags$details(
          open = FALSE,
          shiny::tags$summary("Merge / relabel values (optional)"),
          shiny::p(style = "font-size:12px;color:#777;",
                   "Real data is often messy -- \"female\"/\"Female\"/\"FEMALE\" meant to be one group, ",
                   "not three. Select rows below and relabel them to merge -- e.g. select \"F\" and ",
                   "\"female\" and relabel both to \"Female\"."),
          shiny::checkboxInput("fs_group_merge_case", "Merge values that only differ by case or spacing", TRUE),
          shinycssloaders::withSpinner(DT::DTOutput("fs_group_map_table"), type = 6),
          shiny::fluidRow(
            shiny::column(6, shiny::textInput("fs_group_new_label", "Merge selected into label", "")),
            shiny::column(6, shiny::br(), shiny::actionButton("fs_group_apply_relabel", "Apply"))
          ),
          shiny::actionButton("fs_group_reset_map", "Reset mapping", class = "btn-warning")
        ),
        shiny::checkboxGroupInput("fs_group_values", "Include these values", choices = NULL)
      ),

      shiny::hr(),
      shiny::tags$details(
        open = FALSE,
        shiny::tags$summary("Population normalization (optional)"),
        shiny::p(style = "font-size:12px;color:#777;",
                 "Divide values by a population figure to forecast incidence (e.g. cases per 100,000) instead of absolute counts."),
        shiny::checkboxInput("fs_use_population", "Normalize by population", FALSE),
        shiny::conditionalPanel(
          condition = "input.fs_use_population == true",
          shiny::tags$strong("Population data from"),
          icon_source_row(
            "fs_pop_source",
            list(
              list(id = "fs_pop_src_file", value = "file", icon = "folder-open", title = "File upload"),
              list(id = "fs_pop_src_env",  value = "env",  icon = "database",    title = "Global environment")
            )
          ),
          shiny::conditionalPanel(
            condition = "input.fs_pop_source == 'file'",
            shiny::fileInput("fs_pop_file", "Population table (CSV / Excel)",
                              accept = c(".csv", ".tsv", ".txt", ".xlsx", ".xls"))
          ),
          shiny::conditionalPanel(
            condition = "input.fs_pop_source == 'env'",
            shiny::selectInput("fs_pop_env_obj", "Data frame", choices = NULL),
            shiny::actionButton("fs_load_pop_env", "Load")
          ),
          shiny::selectInput("fs_pop_date_col", "Population key column (year or date)", choices = NULL),
          shiny::selectInput("fs_pop_value_col", "Population column", choices = NULL),
          shiny::conditionalPanel(
            condition = "input.fs_group_col != ''",
            shiny::selectInput("fs_pop_group_col", "Population Grouping Column (optional, matches your data's grouping)",
                                choices = c("(none) -- apply to the overall series only" = ""))
          ),
          shiny::radioButtons("fs_pop_freq", "Population is given per",
                               choices = c("Year" = "year", "Month" = "month"),
                               selected = "year", inline = TRUE),
          shiny::numericInput("fs_pop_multiplier", "Population multiplier", value = 1),
          shiny::numericInput("fs_unit_scale", "Unit divisor (e.g. 100000 for per-100k)", value = 1),
          shiny::tableOutput("fs_pop_preview")
        )
      ),

      shiny::actionButton("fs_finalize_data", "Finalize Dataset", class = "btn-success")
    ),
    shiny::mainPanel(
      shiny::h4("Preview"),
      shiny::tableOutput("fs_data_preview"),
      shiny::downloadButton("fs_download_dataset_csv", "Download Processed Dataset (CSV)"),
      shiny::hr(),
      shiny::h4("Recommended Model"),
      shiny::p(style = "font-size:12px;color:#777;",
               "A quick, no-fitting heuristic based on trend/seasonality/regularity. Holiday configuration below affects this."),
      shiny::tableOutput("fs_recommendation")
    )
  )
}

build_model_tab_ui <- function() {
  shiny::sidebarLayout(
    shiny::sidebarPanel(
      shiny::uiOutput("fs_model_choice_ui"),
      shiny::sliderInput("fs_horizon_months", "Forecast Horizon (months)", min = 1, max = 60, value = 12),
      shiny::sliderInput("fs_test_months", "Manual Test Window (months)", min = 1, max = 36, value = 6),

      shiny::conditionalPanel(
        condition = "input.fs_model_choice == 'prophet'",
        shiny::sliderInput("fs_cp", "Changepoint Prior Scale", min = 0.01, max = 0.5, value = 0.05, step = 0.01),
        shiny::sliderInput("fs_season", "Seasonality Prior Scale", min = 1, max = 20, value = 10),
        shiny::sliderInput("fs_holiday_prior", "Holiday Prior Scale", min = 0.1, max = 10, value = 5, step = 0.1),
        shiny::checkboxInput("fs_yearly", "Yearly Seasonality", TRUE),
        shiny::checkboxInput("fs_weekly", "Weekly Seasonality", TRUE),
        shiny::checkboxInput("fs_daily", "Daily Seasonality", FALSE),
        shiny::checkboxInput("fs_exclude_sundays", "Exclude Sundays", FALSE)
      ),

      shiny::conditionalPanel(
        condition = "input.fs_model_choice == 'arima' || input.fs_model_choice == 'sarima'",
        shiny::radioButtons("fs_arima_mode", "Order Selection",
                             choices = c("Auto-select (auto.arima)" = "auto", "Manual entry" = "manual"),
                             selected = "auto"),
        shiny::conditionalPanel(
          condition = "input.fs_arima_mode == 'manual'",
          shiny::fluidRow(
            shiny::column(4, shiny::numericInput("fs_p", "p", 1, min = 0)),
            shiny::column(4, shiny::numericInput("fs_d", "d", 1, min = 0)),
            shiny::column(4, shiny::numericInput("fs_q", "q", 1, min = 0))
          ),
          shiny::conditionalPanel(
            condition = "input.fs_model_choice == 'sarima'",
            shiny::fluidRow(
              shiny::column(4, shiny::numericInput("fs_P", "P", 0, min = 0)),
              shiny::column(4, shiny::numericInput("fs_D", "D", 0, min = 0)),
              shiny::column(4, shiny::numericInput("fs_Q", "Q", 0, min = 0))
            )
          )
        )
      ),

      shiny::conditionalPanel(
        condition = "input.fs_model_choice == 'lstm'",
        shiny::fluidRow(
          shiny::column(6, shiny::numericInput("fs_lstm_epochs", "Epochs", 50, min = 1)),
          shiny::column(6, shiny::numericInput("fs_lstm_hidden", "Hidden units", 32, min = 1))
        ),
        shiny::fluidRow(
          shiny::column(6, shiny::numericInput("fs_lstm_lookback", "Lookback window", 12, min = 1)),
          shiny::column(6, shiny::numericInput("fs_lstm_lr", "Learning rate", 0.01, min = 0.0001, step = 0.001))
        )
      ),

      shiny::uiOutput("fs_fit_groups_ui"),
      shiny::actionButton("fs_fit_btn", "Fit & Forecast", class = "btn-primary", width = "100%"),
      shiny::tags$details(
        open = FALSE,
        shiny::tags$summary("Plot Appearance"),
        shiny::checkboxInput("fs_show_trend", "Show Trend", TRUE),
        shiny::checkboxInput("fs_show_uncertainty", "Show Uncertainty (CI)", TRUE),
        shiny::checkboxInput("fs_show_holidays", "Show Holiday Markers", TRUE),
        shiny::checkboxInput("fs_show_changepoints", "Show Changepoints", FALSE),
        colourpicker::colourInput("fs_color_actual", "Actual line", value = "#1b9e77"),
        colourpicker::colourInput("fs_color_forecast", "Forecast line", value = "#d95f02"),
        colourpicker::colourInput("fs_color_trend", "Trend line", value = "#7570b3"),
        colourpicker::colourInput("fs_color_ci", "Uncertainty fill", value = "#1b9e77")
      ),
      shiny::hr(),
      shiny::h5("Compare Models"),
      shiny::uiOutput("fs_compare_choices_ui"),
      shiny::actionButton("fs_compare_btn", "Compare Selected Models", width = "100%"),
      shiny::hr(),
      shiny::h5("Cross-Validation"),
      shiny::p(style = "font-size:12px;color:#777;",
               "Refits the currently viewed series at several earlier cutoffs (walk-forward, expanding training window) instead of relying on one train/test split -- more expensive, especially for Prophet/TBATS."),
      shiny::numericInput("fs_cv_folds", "Number of folds", value = 3, min = 1, max = 10, step = 1),
      shiny::actionButton("fs_run_cv", "Run Cross-Validation", width = "100%")
    ),
    shiny::mainPanel(
      shiny::uiOutput("fs_group_view_ui"),
      shiny::uiOutput("fs_holiday_note"),
      shinycssloaders::withSpinner(plotly::plotlyOutput("fs_forecast_plot"), type = 6),
      shiny::downloadButton("fs_download_forecast_png", "Download Plot (PNG)"),
      shiny::h4("Metrics"),
      shinycssloaders::withSpinner(DT::DTOutput("fs_metrics_table"), type = 6),
      shiny::h4("Cross-Validation"),
      shinycssloaders::withSpinner(DT::DTOutput("fs_cv_table"), type = 6),
      shiny::hr(),
      shiny::h4("All Groups (overlay)"),
      shinycssloaders::withSpinner(plotly::plotlyOutput("fs_group_overlay_plot"), type = 6),
      shiny::downloadButton("fs_download_group_overlay_png", "Download Group Overlay (PNG)"),
      shiny::hr(),
      shiny::h4("Model Comparison"),
      shinycssloaders::withSpinner(plotly::plotlyOutput("fs_comparison_plot"), type = 6),
      shiny::downloadButton("fs_download_comparison_png", "Download Combined Plot (PNG)"),
      shinycssloaders::withSpinner(DT::DTOutput("fs_comparison_table"), type = 6),
      shiny::hr(),
      shiny::tags$details(
        open = FALSE,
        shiny::tags$summary("Show Code"),
        shiny::p(style = "font-size:12px;color:#777;",
                 "The R code that reproduces what you just ran, using forecastsuite directly -- like esquisse's code preview for its plot builder. Regenerates after each Fit & Forecast / Compare click."),
        shiny::verbatimTextOutput("fs_generated_code"),
        shiny::downloadButton("fs_download_code", "Download as .R")
      )
    )
  )
}

build_app_ui <- function() {
  shiny::fluidPage(
    shinyjs::useShinyjs(),
    shiny::tags$head(shiny::tags$link(rel = "stylesheet", href = "fs-www/styles.css")),
    shiny::titlePanel("forecastsuite -- Local Multi-Model Forecast App"),
    shiny::wellPanel(
      shiny::fluidRow(
        shiny::column(6, shiny::downloadButton("fs_download_project", "Save Project (.rds)", width = "100%")),
        shiny::column(6, shiny::fileInput("fs_project_file", "Load Project (.rds)", accept = ".rds"))
      ),
      shiny::p(style = "font-size:12px;color:#777;margin-bottom:0;",
               "Saves the finalized dataset(s), holidays, and every setting on the Model tab. Fitted results ",
               "are not saved -- loading a project restores your setup, and you click Fit & Forecast again.")
    ),
    shiny::tabsetPanel(
      id = "fs_tabs",
      shiny::tabPanel("1. Import Data", value = "import_tab", build_import_tab_ui()),
      shiny::tabPanel("2. Holidays", value = "holidays_tab", build_holidays_tab_ui()),
      shiny::tabPanel("3. Model", value = "model_tab", build_model_tab_ui()),
      shiny::tabPanel("Model Guide", value = "guide_tab", build_guide_tab_ui())
    )
  )
}
