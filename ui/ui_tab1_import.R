tabPanel("Data Import & Settings",
         sidebarLayout(
           sidebarPanel(
             width = 4,
             tabsetPanel(id = "import_steps", type = "tabs",
                         
                         # Step 1: Main Dataset
                         tabPanel("1️⃣ Main Data",
                                  h4("📂 Upload Main Dataset"),
                                  import_panel_ui("main", label = "Time Series"),
                                  hr(),
                                  h5("📈 Time Series Settings"),
                                  radioButtons("data_type", "Data Format:",
                                               choices = c("Aggregated Time Series" = "agg", "Individual Observations" = "individual"),
                                               selected = character(0)
                                  ),
                                  selectInput("model_date_col", "Date Column", choices = NULL),
                                  div(id = "model_value_col_wrapper",
                                      selectInput("model_value_col", "Value Column", choices = NULL)
                                  ),
                                  radioButtons("date_agg", "Aggregation Frequency:",
                                               choices = c("Hourly" = "hour", "Daily" = "day", "Weekly" = "week", "Monthly" = "month"),
                                               selected = "day"
                                  ),
                                  actionButton("transform_main", "🛠️ Transform Main Data", class = "btn-primary")
                         ),
                         
                         # Step 2: Population Dataset (Optional)
                         tabPanel("2️⃣ Population (Optional)",
                                  h4(icon("users"), " Population Dataset"),
                                  radioButtons("use_population", "Normalize by population?",
                                               choices = c("Yes" = "yes", "No" = "no"), selected = "no"
                                  ),
                                  conditionalPanel(
                                    condition = "input.use_population == 'yes'",
                                    tagList(
                                      import_panel_ui("pop", label = "Population"),
                                      uiOutput("pop_col_ui"),
                                      radioButtons("pop_freq", "Population Time Scale:",
                                                   choices = c("Yearly" = "year", "Monthly" = "month")),
                                      actionButton("finalize_population", "✅ Finalize Population Data", class = "btn-info")
                                    )
                                  )
                         ),
                         
                         # Step 3: Finalize and Process
                         tabPanel("3️⃣ Finalize",
                                  h4("✅ Finalize Processed Dataset"),
                                  
                                  conditionalPanel(
                                    condition = "input.use_population == 'yes'",
                                    tagList(
                                      h5("⚙️ Population Normalization Settings"),
                                      numericInput("pop_multiplier", "Population Multiplier", value = 1),
                                      numericInput("unit_scale", "Unit Divisor", value = 1)
                                    )
                                  ),
                                  
                                  actionButton("process_data", "📦 Process & Save Final Dataset", class = "btn-success"),
                                  hr(),
                                  h5("Preview Final Dataset"),
                                  tableOutput("dataPreview"),
                                  downloadButton("download_processed", "📥 Download Processed CSV")
                         )
             )
           ),
           
           mainPanel(
             width = 8,
             h4("Main Dataset Preview"),
             tableOutput("main_preview"),
             hr(),
             h4("Population Dataset Preview"),
             tableOutput("pop_preview")
           )
         )
)