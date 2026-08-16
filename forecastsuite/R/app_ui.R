# Bundled local Shiny app UI. Three tabs mirroring the hosted app's
# workflow (import -> holidays -> model), collapsed into one unified
# "Model" tab that works across every registered model instead of having
# separate Forecast/ARIMA tabs like the hosted app does.

build_import_tab_ui <- function() {
  shiny::sidebarLayout(
    shiny::sidebarPanel(
      shiny::fileInput("fs_file", "Upload CSV", accept = ".csv"),
      shiny::selectInput("fs_date_col", "Date Column", choices = NULL),
      shiny::selectInput("fs_value_col", "Value Column", choices = NULL),
      shiny::radioButtons("fs_date_agg", "Aggregation Frequency",
                           choices = c("Hourly" = "hour", "Daily" = "day", "Weekly" = "week", "Monthly" = "month"),
                           selected = "day"),
      shiny::actionButton("fs_finalize_data", "Finalize Dataset", class = "btn-success")
    ),
    shiny::mainPanel(
      shiny::h4("Preview"),
      shiny::tableOutput("fs_data_preview"),
      shiny::hr(),
      shiny::h4("Recommended Model"),
      shiny::p(style = "font-size:12px;color:#777;",
               "A quick, no-fitting heuristic based on trend/seasonality/regularity. Holiday configuration below affects this."),
      shiny::tableOutput("fs_recommendation")
    )
  )
}

build_holidays_tab_ui <- function() {
  shiny::sidebarLayout(
    shiny::sidebarPanel(
      shiny::checkboxInput("fs_use_sundays", "Treat Sundays as a holiday", FALSE),
      shiny::hr(),
      shiny::h5("Add a holiday"),
      shiny::dateInput("fs_manual_holiday_date", "Date"),
      shiny::textInput("fs_manual_holiday_label", "Label"),
      shiny::checkboxInput("fs_manual_holiday_recurring", "Repeat every year in dataset range", TRUE),
      shiny::actionButton("fs_add_manual_holiday", "Add"),
      shiny::actionButton("fs_clear_holidays", "Clear All", class = "btn-warning"),
      shiny::hr(),
      shiny::actionButton("fs_finalize_holidays", "Finalize Holidays", class = "btn-info")
    ),
    shiny::mainPanel(
      shiny::tableOutput("fs_holidays_preview")
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

      shiny::actionButton("fs_fit_btn", "Fit & Forecast", class = "btn-primary", width = "100%"),
      shiny::hr(),
      shiny::h5("Compare Models"),
      shiny::uiOutput("fs_compare_choices_ui"),
      shiny::actionButton("fs_compare_btn", "Compare Selected Models", width = "100%")
    ),
    shiny::mainPanel(
      shiny::uiOutput("fs_holiday_note"),
      shinycssloaders::withSpinner(plotly::plotlyOutput("fs_forecast_plot"), type = 6),
      shiny::h4("Metrics"),
      shinycssloaders::withSpinner(DT::DTOutput("fs_metrics_table"), type = 6),
      shiny::hr(),
      shiny::h4("Model Comparison"),
      shinycssloaders::withSpinner(DT::DTOutput("fs_comparison_table"), type = 6),
      shiny::hr(),
      shiny::tags$details(
        open = FALSE,
        shiny::tags$summary("🧑‍💻 Show Code"),
        shiny::p(style = "font-size:12px;color:#777;",
                 "The R code that reproduces what you just ran, using forecastsuite directly — like esquisse's code preview for its plot builder. Regenerates after each Fit & Forecast / Compare click."),
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
    shiny::titlePanel("forecastsuite — Local Multi-Model Forecast App"),
    shiny::tabsetPanel(
      id = "fs_tabs",
      shiny::tabPanel("1. Import Data", value = "import_tab", build_import_tab_ui()),
      shiny::tabPanel("2. Holidays", value = "holidays_tab", build_holidays_tab_ui()),
      shiny::tabPanel("3. Model", value = "model_tab", build_model_tab_ui())
    )
  )
}
