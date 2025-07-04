tabPanel("Data Import & Settings",
         
         sidebarLayout(
           sidebarPanel(
             h4("📂 Upload Main Dataset"),
             
             # File upload panel for main dataset
             import_panel_ui("main", label = "Time Series"),
             
             hr(),
             h5("📈 Time Series Settings"),
             radioButtons("data_type", "Data Format:",
                          choices = c("Aggregated Time Series" = "agg", "Individual Observations" = "individual")),
             selectInput("model_date_col", "Date Column (for Prophet)", choices = NULL),
             selectInput("model_value_col", "Value Column (for Prophet)", choices = NULL),
             radioButtons("date_agg", "Aggregation Frequency:",
                          choices = c("Daily" = "day", "Weekly" = "week", "Monthly" = "month")),
             
             hr(),
             h4(tagList(icon("users"), " Population Dataset (Optional)")),
             import_panel_ui("pop", label = "Population"),
             uiOutput("pop_col_ui"),
             hr(),
             numericInput("pop_multiplier", "Population Multiplier (unit of population in dataset", value = 1),
             numericInput("unit_scale", "Unit Divisor (incidence per population)", value = 1),
             radioButtons("pop_freq", "Population Time Scale:", choices = c("Yearly" = "year", "Monthly" = "month"))
           ),
           
           mainPanel(
             h4("Main Dataset Preview"),
             DT::DTOutput("main_preview"),
             hr(),
             h4("Population Dataset Preview"),
             DT::DTOutput("pop_preview"),
             hr(),
             h4("Final Processed Dataset (ds & y)"),
             DT::DTOutput("dataPreview"),
             downloadButton("download_processed", "📥 Download Processed CSV")
           )
         )
)