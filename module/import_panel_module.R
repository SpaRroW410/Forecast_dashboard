# import_panel_module.R
library(shiny)
library(shinyjs)
library(shinyBS)

source("module/import_method_module.R")

# UI Function
import_panel_ui <- function(id, label = NULL, tooltip = "Upload Dataset") {
  ns <- NS(id)
  
  tagList(
    useShinyjs(),
    actionButton(ns("main_import_btn"), label = label, icon = icon("file-upload")),
    bsTooltip(ns("main_import_btn"), tooltip, placement = "right", options = list(container = "body")),
    hidden(
      div(
        id = ns("main_import_panel"),
        class = "fade-in",
        h3("Choose Import Method"),
        div(
          class = "icon-vertical",
          actionLink(ns("method_file"), label = NULL, icon = icon("folder-open"), class = "icon-btn", title = "Files"),
          actionLink(ns("method_env"), label = NULL, icon = icon("database"), class = "icon-btn", title = "Environment"),
          actionLink(ns("method_gsheets"), label = NULL, icon = icon("google"), class = "icon-btn", title = "Google Sheets"),
          actionLink(ns("method_copypaste"), label = NULL, icon = icon("keyboard"), class = "icon-btn", title = "Copy-Paste"),
          actionLink(ns("method_url"), label = NULL, icon = icon("link"), class = "icon-btn", title = "URL")
        ),
        br(),
        uiOutput(ns("method_ui"))
      )
    )
  )
}

# Server Function
import_panel_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    observeEvent(input$main_import_btn, {
      toggle("main_import_panel", anim = TRUE, animType = "fade")
    })
    
    # Submodules
    file      <- import_method_server("file")
    env       <- import_method_server("env")
    gsheets   <- import_method_server("gsheets")
    copypaste <- import_method_server("copypaste")
    url       <- import_method_server("url")
    
    # Track selected method
    selected_method <- reactiveVal(NULL)
    
    observeEvent(input$method_file,      selected_method("file"))
    observeEvent(input$method_env,       selected_method("env"))
    observeEvent(input$method_gsheets,   selected_method("gsheets"))
    observeEvent(input$method_copypaste, selected_method("copypaste"))
    observeEvent(input$method_url,       selected_method("url"))
    
    # Render the correct UI
    output$method_ui <- renderUI({
      req(selected_method())
      switch(
        selected_method(),
        file       = import_method_ui(ns("file"), from = "file"),
        env        = import_method_ui(ns("env"), from = "env"),
        gsheets    = import_method_ui(ns("gsheets"), from = "googlesheets"),
        copypaste  = import_method_ui(ns("copypaste"), from = "copypaste"),
        url        = import_method_ui(ns("url"), from = "url")
      )
    })
    
    # Return the selected data safely
    imported_data <- reactive({
      method <- selected_method()
      req(!is.null(method), length(method) == 1)
      
      switch(
        method,
        file       = file$data(),
        env        = env$data(),
        gsheets    = gsheets$data(),
        copypaste  = copypaste$data(),
        url        = url$data(),
        NULL
      )
    })
    
    return(imported_data)
  })
}
