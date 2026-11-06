tabPanel("SARIMA Model",
         value = "sarima_tab",
         fluidRow(
           column(12,
                  tags$p(style = "color:#7a5c00; background-color:#fff3cd; padding:8px; border-radius:4px;",
                         "ℹ️ SARIMA: automatic seasonal order search (auto.arima, seasonal = TRUE). No holiday effects. The forecast horizon follows the Forecast Horizon slider on the Forecast & Evaluation tab."),
                  h4("📈 Series used for fitting (missing dates filled)"),
                  DT::DTOutput("sarima_data_preview"),
                  hr(),
                  actionButton("fit_sarima", "Fit SARIMA Model"),
                  textOutput("sarima_note"),
                  verbatimTextOutput("sarima_summary"),
                  plotOutput("sarima_plot"),
                  downloadButton("download_sarima_plot", "Forecast plot (PNG)")
           )
         )
)
