# The UI files under ui/, module/ and server/ contain UTF-8 emoji and are
# read with source(), which decodes them using the session's locale. In a
# non-UTF-8 locale (e.g. a hosting container started with LANG unset, i.e.
# "C"/"POSIX") every emoji renders as raw bytes such as "<f0><9f><93><98>".
# Switch the character-type locale to UTF-8 when it isn't already, before
# anything is source()d. (source(encoding = "UTF-8") is NOT a substitute:
# under a POSIX locale it fails to parse these files at all.)
if (!isTRUE(l10n_info()[["UTF-8"]])) {
  for (utf8_locale in c("C.UTF-8", "C.utf8", "en_US.UTF-8", "en_US.utf8")) {
    if (nzchar(suppressWarnings(Sys.setlocale("LC_CTYPE", utf8_locale)))) break
  }
  rm(utf8_locale)
}

# Plain library() calls, not pacman::p_load(): p_load() silently tries to
# INSTALL any missing package at app start-up, which on a hosted runtime
# turns a missing dependency into a slow network install inside the start-up
# timeout instead of a clear "there is no package called ..." error.
library(shiny)
library(tibble)
library(shinyjs)
library(shinyBS)
library(DT)
library(bslib)
library(datamods)
library(dplyr)
library(lubridate)
library(ggplot2)
library(prophet)
library(plotly)
library(shinycssloaders)
library(tidyr)
library(colourpicker)
library(zoo)
library(forecast)
library(stringr)
library(readxl)

# Shiny's 5MB upload default is too small for a real-world dataset export;
# raise it and let datamods' own upload-failure notification surface the
# (now much larger) limit instead of a silent, unexplained failure.
options(shiny.maxRequestSize = 30 * 1024^2)

# 🎨 Sepia theme
# local = FALSE: let the browser fetch the font from Google Fonts instead of
# having the R server download/self-host it at startup (bslib's default).
# Connect Cloud's container can't reach fonts.googleapis.com from inside its
# own runtime sandbox, so a local download here times out and crashes the
# app before it ever serves a page -- moving the fetch client-side avoids
# that entirely.
sepia_theme <- bs_theme(
  version = 5,
  base_font = font_google("Noto Serif", local = FALSE)
)


footer_ui <- tags$div(
  style = "text-align: center; margin-top: 30px; padding: 10px;",
  tags$p(style = "font-size:13px; color:#555;",
         HTML("📦 <strong>Forecast Dashboard v0.7.0</strong> &nbsp; | &nbsp; by Dr. Mukul Maheshwari")),
  tags$p(style = "font-size:12px; color:#aaa; margin-top: -8px;",
         HTML("🔍 Powered in part by Microsoft Copilot for design guidance & diagnostics"))
)

# 📁 Load helpers
source("helpers/data_utils.R", local = TRUE)
source("helpers/modeling_functions.R", local = TRUE)
source("helpers/plot_utils.R", local = TRUE)
source("helpers/metric_utils.R", local = TRUE)
source("helpers/holidays_helpers.R", local = TRUE)
source("helpers/recommend_utils.R", local = TRUE)

# 📦 Load modules
source("module/import_panel_module.R", local = TRUE)

# 🧩 Load UI tabs
tab1 <- source("ui/ui_tab1_import.R", local = TRUE)$value
tab2 <- source("ui/ui_tab2_holidays.R", local = TRUE)$value
tab3 <- source("ui/ui_tab3_forecast.R", local = TRUE)$value
tab4 <- source("ui/ui_tab4_arima.R", local = TRUE)$value
tab4b <- source("ui/ui_tab_sarima.R", local = TRUE)$value
tab5 <- source("ui/model_guides.R", local = TRUE)$value
tab6 <- source("ui/ui_tab_app_guide.R", local = TRUE)$value

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
        h3("Loading Forecast Dashboard...", style = "color: #5c4033; margin-bottom: 20px;")
      ),
      type = 4,
      color = "#8B4513"
    )
  ),
  
  titlePanel("📈 Forecast Dashboard", windowTitle = "Forecast Dashboard"),
  
  tabsetPanel(
    id = "main_tabs",
    tab1,
    tab2,
    tab3,
    tab4,
    tab4b,
    tab5,
    tab6
  ),
  footer_ui
)

# 🧠 Server
source("server/server_data_import.R", local = TRUE)
source("server/server_holidays.R", local = TRUE)
source("server/server_forecast.R", local = TRUE)
source("server/server_arima.R", local = TRUE)
source("server/server_sarima.R", local = TRUE)
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
  hideTab("main_tabs", "sarima_tab")

  # ✅ Show tabs and initialize modules when data is ready
  observeEvent(data_import$is_ready(), {
    if (data_import$is_ready()) {
      showTab("main_tabs", "holiday_tab")
      showTab("main_tabs", "forecast_tab")
      showTab("main_tabs", "arima_tab")
      showTab("main_tabs", "sarima_tab")

      # Only initialize holidays module if dataset is valid
      req(data_import$dataset())
      final_holidays_reactive <- holidays_server(input, output, session, data_import$dataset)

      # Only initialize forecast module if holidays are ready
      forecast_server(input, output, session, data_import$dataset, final_holidays_reactive)

      # ARIMA (non-seasonal order search) and SARIMA (seasonal) each fit and
      # plot independently -- essential functions only, no cross-model compare.
      arima_server(input, output, session, data_import$dataset)
      sarima_server(input, output, session, data_import$dataset)
    }
      })
  
  # 📘 Always-on model guide tab
  model_guide_server(input, output, session)
}


# 🚀 Launch app
shinyApp(ui = ui, server = server)