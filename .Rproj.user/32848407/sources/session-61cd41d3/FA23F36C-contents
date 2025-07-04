tabPanel("ARIMA Model",
         fluidRow(
           column(12,
                  h4("📈 Time Series with Missing Dates Filled"),
                  DT::DTOutput("arima_data_preview"),
                  hr(),
                  actionButton("fit_arima", "Fit ARIMA Model"),
                  verbatimTextOutput("arima_summary"),
                  plotOutput("arima_plot")
           )
         )
)