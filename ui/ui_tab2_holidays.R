tabPanel(title = "Holiday Settings",
         value = "holiday_tab",
         useShinyjs(),
         tabsetPanel(id = "holiday_main_tabs", type = "tabs",
                     
                     # 1️⃣ Holiday Import and Fixed Holidays
                     tabPanel("1️⃣ Holiday Import and Fixed Holidays",
                              radioButtons("use_holiday_effects", "Enable Holiday Effects:",
                                           choices = c("Yes" = "yes", "No" = "no"),
                                           selected = "no",
                                           inline = TRUE
                              ),
                              
                              conditionalPanel(condition = "input.use_holiday_effects == 'yes'",
                                               import_panel_ui("hol", label = "Import Movable Holidays"),
                                               
                                               uiOutput("movable_date_col"),
                                               uiOutput("movable_label_col"),
                                               
                                               actionButton("finalize_movable", "🧩 Finalize Movable Holidays", class = "btn-success"),
                                               hr(),
                                               
                                               sliderInput("holiday_years", "Fixed Holiday Year Range",
                                                           min = 2000, max = 2035, value = c(2015, 2025)),
                                               checkboxInput("include_sundays", "Include Sundays as Holidays", value = TRUE),
                                               
                                               checkboxGroupInput("fixed_holidays", "Select Fixed Holidays:",
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
                                               
                                               actionButton("compile_fixed_holidays", "🧮 Generate Holidays", width = "100%")
                              )
                     ),
                     # 2️⃣ Manual Entry & Window Effects
                     tabPanel("2️⃣ Manual Entries & Window Effects",
                              radioButtons("manual_type", "Holiday Type:",
                                           choices = c("Fixed (recurring every year)" = "fixed",
                                                       "Movable (specific year only)" = "movable"),
                                           inline = TRUE
                              ),
                              fluidRow(
                                column(6, dateInput("manual_date", "Date")),
                                column(6, textInput("manual_label", "Holiday Label"))
                              ),
                              actionButton("add_manual", "➕ Add Manual Holiday"),
                              hr(),
                              
                              h5("📐 Configure Holiday Window Effects"),
                              selectInput("window_label", "Select Holiday Label:", choices = NULL),
                              numericInput("lower_window", "Lower Window (days before)", value = 0),
                              numericInput("upper_window", "Upper Window (days after)", value = 0),
                              actionButton("apply_window", "📌 Apply Window Settings"),
                              DTOutput("window_table"),
                              hr(),
                              
                              h5("📋 Manual Holiday Table"),
                              DTOutput("manual_table", width = "100%"),
                              actionButton("remove_manual", "❌ Remove Selected", width = "100%")
                     ),
                     
                     # 3️⃣ Contingency Check
                     tabPanel("3️⃣ Contingency Check",
                              h4("Holiday Contingency Analysis"),
                              radioButtons("enable_contingency", "Show Contingency Analysis:",
                                           choices = c("Yes" = "yes", "No" = "no"),
                                           selected = "no", inline = TRUE
                              ),
                              conditionalPanel(
                                condition = "input.enable_contingency == 'yes'",
                                helpText("This section analyzes holidays with non-zero values, and dates that are consistently zero or missing."),
                                uiOutput("holiday_contingency_ui")
                              )
                     ),
                     
                     # 4️⃣ Final Holidays & Label Editing
                     tabPanel("4️⃣ Final Holidays & Label Editing",
                              h4("📆 Combined Holiday Preview"),
                              verbatimTextOutput("holiday_summary"),
                              div(style = "max-height:400px; overflow-y:auto; border:1px solid #ccc; padding:5px;",
                                  withSpinner(DTOutput("final_holiday_table"), type = 4, color = "#2c3e50")
                              ),
                              hr(),
                              
                              h5("✏️ Edit Holiday Label"),
                              verbatimTextOutput("selected_holiday_info"),
                              textInput("edit_label", "New Label"),
                              actionButton("apply_edit", "✅ Apply Label Change"),
                              hr(),
                              
                              h4("📊 Summary of Holiday Types"),
                              verbatimTextOutput("holiday_summary_stats"),
                              
                              checkboxInput("confirm_finalize", "✅ Finalize Holiday List", value = FALSE),
                              helpText("Finalizing will remove all temporary holiday inputs from memory and create a clean holiday dataset."),
                              downloadButton("download_holidays", "📥 Download Final Holidays")
                     )
         )
)