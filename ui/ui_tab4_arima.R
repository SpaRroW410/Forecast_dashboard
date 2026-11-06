tabPanel("ARIMA Model",
         value = "arima_tab",
         fluidRow(
           column(12,
                  tags$p(style = "color:#7a5c00; background-color:#fff3cd; padding:8px; border-radius:4px;",
                         "ℹ️ ARIMA: automatic non-seasonal order search (auto.arima, seasonal = FALSE). No holiday effects. The forecast horizon follows the Forecast Horizon slider on the Forecast & Evaluation tab. See the SARIMA tab for a seasonal fit."),
                  h4("📈 Series used for fitting (missing dates filled)"),
                  DT::DTOutput("arima_data_preview"),
                  hr(),
                  actionButton("fit_arima", "Fit ARIMA Model"),
                  verbatimTextOutput("arima_summary"),
                  plotOutput("arima_plot"),
                  downloadButton("download_arima_plot", "Forecast plot (PNG)")
           )
         )
)