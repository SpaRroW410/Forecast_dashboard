tabPanel("ARIMA Model",
         value = "arima_tab",
         fluidRow(
           column(12,
                  tags$p(style = "color:#7a5c00; background-color:#fff3cd; padding:8px; border-radius:4px;",
                         "ℹ️ ARIMA does not model holiday effects — non-seasonal order search only. See the SARIMA tab for a seasonal fit."),
                  h4("📈 Time Series with Missing Dates Filled"),
                  DT::DTOutput("arima_data_preview"),
                  hr(),
                  actionButton("fit_arima", "Fit ARIMA Model"),
                  verbatimTextOutput("arima_summary"),
                  plotOutput("arima_plot")
           )
         )
)