library(pacman)
p_load(
  shiny, tibble, shinyjs, shinyBS, DT, bslib, datamods, dplyr,
  lubridate, ggplot2, prophet, plotly, shinycssloaders, tidyr,
  colourpicker, zoo, forecast, stringr
)

# 🎨 Sepia theme
sepia_theme <- bs_theme(
  version = 5,
  base_font = font_google("Noto Serif")
)


footer_ui <- tags$div(
  style = "text-align: center; margin-top: 30px; padding: 10px;",
  tags$p(style = "font-size:13px; color:#555;",
         HTML("📦 <strong>Forecast Dashboard v0.6</strong> &nbsp; | &nbsp; by Dr. Mukul Maheshwari")),
  tags$p(style = "font-size:12px; color:#aaa; margin-top: -8px;",
         HTML("🔍 Powered in part by Microsoft Copilot for design guidance & diagnostics"))
)

# 📁 Load helpers
source("helpers/data_utils.R", local = TRUE)
source("helpers/modeling_functions.R", local = TRUE)
source("helpers/plot_utils.R", local = TRUE)
source("helpers/metric_utils.R", local = TRUE)
source("helpers/holidays_helpers.R", local = TRUE)

# 📦 Load modules
source("module/import_panel_module.R", local = TRUE)

# 🧩 Load UI tabs
tab1 <- source("ui/ui_tab1_import.R", local = TRUE)$value
tab2 <- source("ui/ui_tab2_holidays.R", local = TRUE)$value
tab3 <- source("ui/ui_tab3_forecast.R", local = TRUE)$value
tab4 <- source("ui/ui_tab4_arima.R", local = TRUE)$value
tab5 <- source("ui/model_guides.R", local = TRUE)$value

# 🖼️ UI
ui <- fluidPage(
  useShinyjs(),
  tags$head(
    tags$link(rel = "stylesheet", href = "styles.css"),
    tags$style(HTML("
      /* Smooth fade transition between tabs */
      .tab-content > .tab-pane {
        transition: opacity 0.5s ease-in-out;
      }
      .tab-content > .tab-pane:not(.active) {
        opacity: 0;
        display: block !important;
        height: 0;
        overflow: hidden;
      }
    "))
  ),
  
  theme = sepia_theme,
  
  # ⏳ Full-page loading screen
  div(
    id = "loading_screen",
    style = "
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      background-color: #fdf6e3;
      z-index: 9999;
      display: flex;
      align-items: center;
      justify-content: center;
      flex-direction: column;
      font-family: 'Noto Serif', serif;
    ",
    withSpinner(
      tagList(
        h3("Loading Prophet Forecast Dashboard...", style = "color: #5c4033; margin-bottom: 20px;")
      ),
      type = 4,
      color = "#8B4513"
    )
  ),
  
  titlePanel("📈 Prophet Forecast Dashboard"),
  
  tabsetPanel(
    id = "main_tabs",
    tab1,
    tab2,
    tab3,
    tab4,
    tab5
  ),
  footer_ui
)

# 🧠 Server
source("server/server_data_import.R", local = TRUE)
source("server/server_holidays.R", local = TRUE)
source("server/server_forecast.R", local = TRUE)
source("server/server_arima.R", local = TRUE)
source("server/model_guide_server.R", local = TRUE)

server <- function(input, output, session) {
  # 🔄 Run data import module
  data_import <- data_import_server(input, output, session)
  
  # ⏳ Hide loading screen once UI is initialized
  observe({
    shinyjs::runjs("
      setTimeout(function() {
        Shiny.setInputValue('ui_ready', true);
      }, 1000);
    ")
  })
  
  observeEvent(input$ui_ready, {
    shinyjs::hide("loading_screen", anim = TRUE, animType = "fade", time = 1)
  })
  
  # 🚫 Hide downstream tabs initially
  hideTab("main_tabs", "holiday_tab")
  hideTab("main_tabs", "forecast_tab")
  hideTab("main_tabs", "arima_tab")

  # ✅ Show tabs and initialize modules when data is ready
  observeEvent(data_import$is_ready(), {
    if (data_import$is_ready()) {
      showTab("main_tabs", "holiday_tab")
      showTab("main_tabs", "forecast_tab")
      showTab("main_tabs", "arima_tab")

      # Only initialize holidays module if dataset is valid
      req(data_import$dataset())
      final_holidays_reactive <- holidays_server(input, output, session, data_import$dataset)

      # Only initialize forecast module if holidays are ready
      forecast_result <- forecast_server(input, output, session, data_import$dataset, final_holidays_reactive)

      # arima model with forecast (missing entry in sequence as NA); compares
      # against the Prophet result once the user fits a forecast
      arima_server(input, output, session, data_import$dataset, forecast_result$forecast_data)
    }
      })
  
  # 📘 Always-on model guide tab
  model_guide_server(input, output, session)
}


# 🚀 Launch app
shinyApp(ui = ui, server = server)