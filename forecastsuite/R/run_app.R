#' Launch the bundled local forecastsuite Shiny app
#'
#' Unlike the hosted Forecast Dashboard app, this exposes every registered,
#' available model (Prophet, ARIMA, SARIMA, ETS, TBATS, NNETAR, Holt-Winters,
#' and LSTM if `torch` is installed) with Plotly always on and no
#' memory-conserving toggles, since it targets local/offline use rather than
#' a free hosting tier.
#'
#' @param data_env The environment whose data frames the Import tab's
#'   "Global environment" source lists and loads from. Defaults to the
#'   environment `run_app()` is called from (the workspace at the console). The
#'   app only reads from it; it never creates or modifies objects there.
#' @param ... Passed through to `shiny::shinyApp(options = list(...))`.
#'
#' @return A `shiny.appobj`, as returned by `shiny::shinyApp()`. Printing it
#'   (e.g. calling `run_app()` at the console, or letting it auto-print)
#'   launches the app; it does not block on its own.
#' @export
#' @examples
#' if (interactive()) {
#'   run_app()
#' }
run_app <- function(data_env = parent.frame(), ...) {
  force(data_env)
  shiny::addResourcePath("fs-www", system.file("www", package = "forecastsuite"))
  server <- function(input, output, session) {
    build_app_server(input, output, session, data_env = data_env)
  }
  shiny::shinyApp(ui = build_app_ui(), server = server, options = list(...))
}
