tabPanel("SARIMA Model",
         value = "sarima_tab",
         fluidRow(
           column(12,
                  tags$p(style = "color:#7a5c00; background-color:#fff3cd; padding:8px; border-radius:4px;",
                         "ℹ️ SARIMA does not model holiday effects — seasonal order search (auto.arima, seasonal = TRUE)."),
                  h4("📈 Time Series with Missing Dates Filled"),
                  DT::DTOutput("sarima_data_preview"),
                  hr(),
                  actionButton("fit_sarima", "Fit SARIMA Model"),
                  verbatimTextOutput("sarima_summary"),
                  plotOutput("sarima_plot")
           )
         )
)
