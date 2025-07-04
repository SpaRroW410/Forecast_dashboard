model_guide_server <- function(input, output, session) {
  output$demoPlot <- renderPlot({
    # Load dataset with local fallback
    if (file.exists("data/female_births.csv")) {
      df <- read.csv("data/female_births.csv")
    } else {
      df <- read.csv("https://raw.githubusercontent.com/jbrownlee/Datasets/master/daily-total-female-births.csv")
    }
    
    df <- df %>%
      rename(ds = Date, y = Births) %>%
      mutate(ds = as.Date(ds))
    
    # Fit Prophet model
    m <- prophet::prophet(
      changepoint.prior.scale = input$demo_cp,
      seasonality.prior.scale = input$demo_season,
      yearly.seasonality = FALSE,
      weekly.seasonality = TRUE,
      daily.seasonality = FALSE
    )
    
    m <- prophet::fit.prophet(m, df)
    future <- prophet::make_future_dataframe(m, periods = 30)
    forecast <- predict(m, future)
    
    # Plot forecast
    p <- plot(m, forecast) +
      ggtitle("Interactive Forecast Demo: Daily Female Births") +
      theme_minimal(base_family = "serif")
    
    if (input$demo_show_trend && "trend" %in% names(forecast)) {
      p <- p + geom_line(aes(y = trend), data = forecast, color = "#1b9e77", linewidth = 1.2)
    }
    
    if (!input$demo_show_uncertainty) {
      p <- p + guides(fill = "none")
    }
    
    p
  })
}