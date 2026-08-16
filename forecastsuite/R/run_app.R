#' Launch the bundled local forecastsuite Shiny app
#'
#' Unlike the hosted Forecast Dashboard app, this exposes every registered,
#' available model (Prophet, ARIMA, SARIMA, ETS, TBATS, NNETAR, Holt-Winters,
#' and LSTM if `torch` is installed) with Plotly always on and no
#' memory-conserving toggles, since it targets local/offline use rather than
#' a free hosting tier.
#'
#' @param ... Passed through to `shiny::shinyApp(options = list(...))`.
#' @export
run_app <- function(...) {
  shiny::addResourcePath("fs-www", system.file("www", package = "forecastsuite"))
  shiny::shinyApp(ui = build_app_ui(), server = build_app_server, options = list(...))
}
