# import_method_module.R
library(shiny)
library(datamods)

# UI for one import method
import_method_ui <- function(id, from) {
  ns <- NS(id)
  datamods::import_ui(ns("import"), from = from)
}

# Server for one import method
import_method_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    datamods::import_server("import")
  })
}
