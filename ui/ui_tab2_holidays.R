tabPanel(title = "Holiday Settings",
         value = "holiday_tab",
         useShinyjs(),
         tabsetPanel(id = "holiday_main_tabs", type = "tabs",

                     # Step 1: imported (movable) holidays, fixed holidays and Sundays
                     tabPanel("Step 1 · Import & fixed",
                              radioButtons("use_holiday_effects", "Set up imported and fixed holidays?",
                                           choices = c("Yes" = "yes", "No" = "no"),
                                           selected = "no",
                                           inline = TRUE
                              ),
                              helpText("Holidays are optional: with no holiday list in use (step 4), forecasts simply run without holiday effects."),

                              conditionalPanel(condition = "input.use_holiday_effects == 'yes'",
                                               h5("Holidays from a file (movable holidays)"),
                                               div(
                                                 downloadButton("download_example_holidays", "Example holiday file (CSV)"),
                                                 tags$div(class = "form-text mb-2",
                                                          "The file needs a date column and a holiday name column.")
                                               ),
                                               import_panel_ui("hol", label = "Add holidays from a file…",
                                                               tooltip = "Import a CSV/Excel file with one row per holiday date"),

                                               uiOutput("movable_date_col"),
                                               uiOutput("movable_label_col"),

                                               actionButton("finalize_movable", "➕ Add these to the holiday list", class = "btn-success"),
                                               hr(),

                                               h5("Fixed holidays and Sundays"),
                                               sliderInput("holiday_years", "Years to generate holidays for",
                                                           min = 2000, max = 2035, value = c(2015, 2025), sep = ""),
                                               helpText("Choose years that cover your data's date range; holidays outside it have no effect on the forecast."),
                                               checkboxInput("include_sundays", "Include every Sunday as a holiday", value = TRUE),

                                               checkboxGroupInput("fixed_holidays", "Fixed holidays (same date every year):",
                                                                  choices = c(
                                                                    "Republic Day (01-26)" = "01-26",
                                                                    "Independence Day (08-15)" = "08-15",
                                                                    "Gandhi Jayanti (10-02)" = "10-02",
                                                                    "Christmas (12-25)" = "12-25",
                                                                    "Ambedkar Jayanti (04-14)" = "04-14",
                                                                    "Makar Sankranti (01-14)" = "01-14"
                                                                  ),
                                                                  selected = c("01-26", "08-15")
                                               ),

                                               actionButton("compile_fixed_holidays", "🧮 Build holiday list (Sundays + fixed + manual)", width = "100%"),
                                               helpText("Adds the Sundays and fixed holidays above, plus any manual entries from step 2, to the working holiday list (review it on step 4).")
                              )
                     ),
                     # Step 2: manual entries and holiday windows
                     tabPanel("Step 2 · Manual & windows",
                              h5("Manual holidays"),
                              helpText("Manual entries join the working holiday list when you click 🧮 Build holiday list on step 1."),
                              radioButtons("manual_type", "Repeats:",
                                           choices = c("Every year (uses the step 1 year range)" = "fixed",
                                                       "Once (this date only)" = "movable"),
                                           inline = TRUE
                              ),
                              fluidRow(
                                column(6, dateInput("manual_date", "Date")),
                                column(6, textInput("manual_label", "Holiday name"))
                              ),
                              actionButton("add_manual", "➕ Add manual holiday"),
                              hr(),

                              h5("📋 Manual entries"),
                              DTOutput("manual_table", width = "100%"),
                              actionButton("remove_manual", "❌ Remove selected", width = "100%"),
                              hr(),

                              h5("📐 Holiday windows"),
                              helpText("Extend a holiday's effect to nearby days, e.g. 2 days before and 1 day after. Windows apply to holidays already in the working holiday list."),
                              selectInput("window_label", "Holiday:", choices = NULL),
                              fluidRow(
                                column(6, numericInput("lower_window", "Days before (0 or negative, e.g. -2)", value = 0, max = 0, step = 1)),
                                column(6, numericInput("upper_window", "Days after (0 or positive, e.g. 1)", value = 0, min = 0, step = 1))
                              ),
                              actionButton("apply_window", "📌 Apply window"),
                              DTOutput("window_table")
                     ),

                     # Step 3: check holidays against the data
                     tabPanel("Step 3 · Check",
                              radioButtons("enable_contingency", "Check the holiday list against my data?",
                                           choices = c("Yes" = "yes", "No" = "no"),
                                           selected = "no", inline = TRUE
                              ),
                              conditionalPanel(
                                condition = "input.enable_contingency == 'yes'",
                                helpText("Shows which holidays fall on days with data, and calendar dates (month-day) that are zero or missing every year: possible closures that aren't declared as holidays yet."),
                                uiOutput("holiday_contingency_ui")
                              )
                     ),

                     # Step 4: review, edit and use the holiday list
                     tabPanel("Step 4 · Review & use",
                              h4("📆 Working holiday list"),
                              textOutput("holiday_summary"),
                              div(style = "max-height:400px; overflow-y:auto; border:1px solid #ccc; padding:5px;",
                                  withSpinner(DTOutput("final_holiday_table"), type = 4, color = "#2c3e50")
                              ),
                              hr(),

                              h5("✏️ Rename a holiday"),
                              textOutput("selected_holiday_info"),
                              textInput("edit_label", "New name"),
                              actionButton("apply_edit", "Apply new name"),
                              hr(),

                              h5("📊 Holiday counts by name"),
                              verbatimTextOutput("holiday_summary_stats"),
                              hr(),

                              h4("✅ Use for forecasting"),
                              helpText("Locks in the working list (with any windows) for the next forecast, then clears the working list so you can start a new one."),
                              actionButton("confirm_finalize", "✅ Use these holidays for forecasting", class = "btn-success"),
                              tags$div(class = "mt-2", strong(textOutput("final_holiday_status", inline = TRUE))),
                              tags$div(class = "mt-2", downloadButton("download_holidays", "Holidays in use (CSV)"))
                     )
         )
)
