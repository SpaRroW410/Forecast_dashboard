# import_panel_module.R
library(shiny)
library(shinyjs)

source("module/import_method_module.R")

# UI Function
# `tooltip` is shown as the button's native hover text (title attribute).
# It used to be a shinyBS::bsTooltip(), but shinyBS only supports Bootstrap 3
# while the app uses bslib's Bootstrap 5, so the tooltip never appeared and
# raised a JavaScript error ('No method named "destroy"') on every page load.
import_panel_ui <- function(id, label = NULL, tooltip = "Import a dataset") {
  ns <- NS(id)

  tagList(
    useShinyjs(),
    actionButton(ns("main_import_btn"), label = label, icon = icon("file-upload"), title = tooltip),
    hidden(
      div(
        id = ns("main_import_panel"),
        class = "fade-in",
        tags$div(class = "form-text mb-2", "Import from:"),
        div(
          class = "icon-vertical",
          actionLink(ns("method_file"), label = tags$span(class = "icon-label", "File"), icon = icon("folder-open"), class = "icon-btn", title = "Upload a file (CSV, TSV, Excel, ...)"),
          actionLink(ns("method_env"), label = tags$span(class = "icon-label", "R data"), icon = icon("database"), class = "icon-btn", title = "Example datasets bundled with R packages"),
          actionLink(ns("method_gsheets"), label = tags$span(class = "icon-label", "Sheets"), icon = icon("google"), class = "icon-btn", title = "A Google Sheet shared by link"),
          actionLink(ns("method_copypaste"), label = tags$span(class = "icon-label", "Paste"), icon = icon("keyboard"), class = "icon-btn", title = "Paste delimited text"),
          actionLink(ns("method_url"), label = tags$span(class = "icon-label", "URL"), icon = icon("link"), class = "icon-btn", title = "A CSV/TSV file at a web address")
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
