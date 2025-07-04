

library(pacman)
p_load(shiny,tibble, shinyjs, shinyBS, DT,bslib,datamods,dplyr,lubridate,ggplot2,tibble, prophet,plotly)


# theme
sepia_theme <- bs_theme(
  version = 5,
  bootswatch = "journal",
  base_font = font_google("Noto Serif")
)

# load helper
source("helpers/data_utils.R", local = TRUE)
source("helpers/modeling_functions.R", local = TRUE)
source("helpers/plot_utils.R", local = TRUE)
source("helpers/metric_utils.R", local = TRUE)
source("helpers/holidays_helpers.R", local = TRUE)

# load module
source("module/import_panel_module.R", local = TRUE)

# load UI files (tab_panel objects)

tab1 <- source("ui/ui_tab1_import.R", local = TRUE)$value
tab2 <- source("ui/ui_tab2_holidays.R", local = TRUE)$value
tab3 <- source("ui/ui_tab3_forecast.R", local = TRUE)$value
tab4 <- source("ui/ui_tab4_arima.R", local = TRUE)$value
tab5 <- source("ui/model_guides.R",local = TRUE)$value


# Define UI
ui <- fluidPage(
  useShinyjs(),
  tags$head(tags$link(rel = "stylesheet", href = "styles.css")),
  theme = sepia_theme,
  titlePanel("📈 Prophet Forecast Dashboard"),
  tabsetPanel(
    tab1,
    tab2,
    tab3,
    tab4,
    tab5
  )
)

# Define server (calls submodules inside)
source("server/server_data_import.R", local = TRUE)
source("server/server_holidays.R", local = TRUE)
source("server/server_forecast.R", local = TRUE)
source("server/server_arima.R", local = TRUE)
source("server/model_guide_server.R",local = TRUE)

# Master server
server <- function(input, output, session) {
  
  # Run data import module and get dataset()
  dataset_reactive <- data_import_server(input, output, session)
  
  
  # Pass dataset() into the holiday settings module
  final_holidays_reactive <- holidays_server(input, output, session, dataset_reactive)
  
  # Use both dataset() and final_holidays() in forecasting
  forecast_server(input, output, session, dataset_reactive, final_holidays_reactive)
  
  # arima model with forecast (missing entry in sequence as NA)
  
  arima_server(input, output, session, dataset_reactive)
  
  # Model guides
  model_guide_server(input, output, session)
  }


# Launch app
shinyApp(ui = ui, server = server)
