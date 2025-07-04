tabPanel("Holiday Settings",
         useShinyjs(),
         sidebarLayout(
           sidebarPanel(
             width = 4,
             tabsetPanel(
               id = "holiday_tabs", type = "tabs",
               
               tabPanel("1️⃣ Sundays & Fixed",
                        checkboxInput("include_sundays", "Include Sundays as Holidays", value = TRUE),
                        hr(),
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
                        sliderInput("holiday_years", "Fixed Holiday Year Range", min = 2000, max = 2035, value = c(2015, 2025))
               ),
               
               tabPanel("2️⃣ Movable Holidays",
                        import_panel_ui("hol", label = "Import Movable Holidays"),
                        DTOutput("movable_preview"),
                        conditionalPanel(
                          condition = "output.movable_preview !== null",
                          h5("🔗 Map Columns"),
                          uiOutput("movable_date_col"),
                          uiOutput("movable_label_col")
                        )
               ),
               
               tabPanel("3️⃣ Manual Entry",
                        radioButtons("manual_type", "Holiday Type:",
                                     choices = c("Fixed (recurring every year)" = "fixed", "Movable (specific year only)" = "movable"),
                                     inline = TRUE
                        ),
                        fluidRow(
                          column(6, dateInput("manual_date", "Date")),
                          column(6, textInput("manual_label", "Holiday Label"))
                        ),
                        actionButton("add_manual", "➕ Add Manual Holiday"),
                        hr(),
                        div(style = "margin-bottom: 10px;", DTOutput("manual_table", width = "100%")),
                        actionButton("remove_manual", "❌ Remove Selected", width = "100%")
               )
             )
           ),
           
           mainPanel(
             width = 8,
             tabsetPanel(
               id = "holiday_main_tabs", type = "tabs",
               
               tabPanel("🧾 Final Holidays",
                        h4("📆 Final Combined Holidays Table"),
                        helpText("Starts with Sundays and selected fixed holidays. Movable and manual holidays will appear once added."),
                        verbatimTextOutput("holiday_summary"),
                        DTOutput("final_holiday_table"),
                        downloadButton("download_holidays", "📥 Download Final Holidays"),
                        hr(),
                        
                        h5("✏️ Edit Holiday Label"),
                        verbatimTextOutput("selected_holiday_info"),
                        textInput("edit_label", "New Label"),
                        actionButton("apply_edit", "✅ Apply Label Change"),
                        hr(),
                        
                        h5("📐 Configure Holiday Window Effects"),
                        selectInput("window_label", "Select Holiday Label:", choices = NULL),
                        numericInput("lower_window", "Lower Window (days before)", value = 0),
                        numericInput("upper_window", "Upper Window (days after)", value = 0),
                        actionButton("apply_window", "📌 Apply Window Settings"),
                        DTOutput("window_table")
               ),
               
               tabPanel("📊 Contingency Check",
                        h4("Holiday Contingency Table"),
                        helpText("Shows holidays with non-zero data, and dates that are always zero or missing."),
                        DTOutput("holiday_contingency")
               )
             )
           )
         )
)