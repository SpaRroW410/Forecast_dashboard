tabPanel("ARIMA Model",
         value = "arima_tab",
         fluidRow(
           column(12,
                  tags$p(style = "color:#7a5c00; background-color:#fff3cd; padding:8px; border-radius:4px;",
                         "ℹ️ ARIMA does not model holiday effects — comparisons below reflect that difference."),
                  h4("📈 Time Series with Missing Dates Filled"),
                  DT::DTOutput("arima_data_preview"),
                  hr(),
                  actionButton("fit_arima", "Fit ARIMA Model"),
                  verbatimTextOutput("arima_summary"),
                  plotOutput("arima_plot"),
                  hr(),
                  h4("📊 Prophet vs. ARIMA — Model Quality Comparison"),
                  actionButton("compare_models_btn", "🔍 Compare Prophet vs ARIMA", width = "100%"),
                  DT::DTOutput("model_comparison_table"),
                  textOutput("model_comparison_summary")
           )
         )
)