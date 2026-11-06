tabPanel("Data Import & Settings",
         sidebarLayout(
           sidebarPanel(
             width = 4,
             tabsetPanel(id = "import_steps", type = "tabs",
                         
                         # Step 1: Main Dataset
                         tabPanel("1️⃣ Main Data",
                                  h4("📂 Main dataset"),
                                  tags$div(class = "form-text mb-2",
                                           "CSV, TSV, Excel, a URL or pasted text. File uploads are limited to 30 MB."),
                                  import_panel_ui("main", label = "Choose data source…",
                                                  tooltip = "Import the time series you want to forecast"),
                                  hr(),
                                  h5("📈 Time Series Settings"),
                                  radioButtons("data_type", "Data format:",
                                               choices = c("Aggregated Time Series" = "agg", "Individual Observations" = "individual"),
                                               selected = character(0)
                                  ),
                                  selectInput("model_date_col", "Date column", choices = NULL),
                                  div(id = "model_value_col_wrapper",
                                      selectInput("model_value_col", "Value column", choices = NULL)
                                  ),
                                  radioButtons("date_agg", "Time step:",
                                               choices = c("Hourly (ARIMA/SARIMA only)" = "hour", "Daily" = "day", "Weekly" = "week", "Monthly" = "month"),
                                               selected = "day"
                                  ),
                                  helpText("Individual observations are counted per time step. Aggregated rows are used as they are, so pick the step your rows already have."),
                                  actionButton("transform_main", "🛠️ Prepare main data", class = "btn-primary")
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
                                      import_panel_ui("pop", label = "Choose population data source…",
                                                      tooltip = "Import population figures by year or month"),
                                      uiOutput("pop_col_ui"),
                                      radioButtons("pop_freq", "Population figures are:",
                                                   choices = c("Yearly" = "year", "Monthly" = "month"), inline = TRUE),
                                      actionButton("finalize_population", "✅ Confirm population data", class = "btn-info")
                                    )
                                  )
                         ),
                         
                         # Step 3: Process
                         tabPanel("3️⃣ Process",
                                  h4("✅ Process the dataset"),
                                  helpText("Processing unlocks the Holiday, Forecast, ARIMA and SARIMA tabs."),
                                  
                                  conditionalPanel(
                                    condition = "input.use_population == 'yes'",
                                    tagList(
                                      h5("⚙️ Population Normalization Settings"),
                                      numericInput("pop_multiplier", "Population multiplier", value = 1),
                                      numericInput("unit_scale", "Unit divisor", value = 1)
                                    )
                                  ),
                                  
                                  actionButton("process_data", "📦 Process dataset", class = "btn-success"),
                                  hr(),
                                  h5("Processed dataset (first rows)"),
                                  tableOutput("dataPreview"),
                                  downloadButton("download_processed", "Processed data (CSV)"),
                                  hr(),
                                  h5("🧭 Recommended Model"),
                                  p(style = "font-size:12px;color:#777;",
                                    "A quick heuristic based on trend, seasonality and regularity (no models are fitted). See the Model Guide tab for how it works. Holidays aren't factored in yet."),
                                  tableOutput("model_recommendation")
                         )
             )
           ),
           
           mainPanel(
             width = 8,
             h4("Main dataset preview"),
             tableOutput("main_preview"),
             conditionalPanel(
               condition = "input.use_population == 'yes'",
               hr(),
               h4("Population dataset preview"),
               tableOutput("pop_preview")
             )
           )
         )
)