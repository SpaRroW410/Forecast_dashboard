# Icon-button source selectors, matching the hosted app's original pattern
# (module/import_panel_module.R): actionLink()s styled ".icon-btn" inside a
# ".icon-vertical" row (both classes already ship in inst/www/styles.css),
# using shiny::icon()'s bundled Font Awesome so no extra dependency is
# needed, with the hover tooltip via the native `title` attribute -- the
# same "tooltip via title attribute" comment appears in the original CSS.
#
# Mechanically this is a hidden radioButtons() driven by the icon clicks
# via updateRadioButtons(), rather than a raw JS bridge: every existing
# conditionalPanel `input.<id> == '...'` condition and every server-side
# `input$<id>` read keeps working completely unchanged, so this can be
# dropped in without touching anything downstream.

icon_source_row <- function(input_id, options, selected = NULL) {
  if (is.null(selected)) selected <- options[[1]]$value
  choices <- stats::setNames(vapply(options, `[[`, "", "value"),
                              vapply(options, `[[`, "", "value"))

  shiny::tagList(
    shiny::div(
      style = "display:none",
      shiny::radioButtons(input_id, NULL, choices = choices, selected = selected)
    ),
    shiny::div(
      class = "icon-vertical",
      lapply(options, function(opt) {
        shiny::actionLink(opt$id, label = NULL, icon = shiny::icon(opt$icon),
                           class = "icon-btn", title = opt$title)
      })
    ),
    shiny::tags$p(
      style = "text-align:center; font-size:12px; color:#777; margin-top:-8px;",
      shiny::textOutput(paste0(input_id, "_label"), inline = TRUE)
    )
  )
}

# Server-side half of icon_source_row(): wires each icon's click to update
# the hidden radio, and renders the label text under the row.
wire_icon_source <- function(input, output, session, input_id, options) {
  for (opt in options) {
    local({
      id <- opt$id
      value <- opt$value
      shiny::observeEvent(input[[id]], {
        shiny::updateRadioButtons(session, input_id, selected = value)
      }, ignoreInit = TRUE)
    })
  }

  labels <- stats::setNames(vapply(options, `[[`, "", "title"),
                             vapply(options, `[[`, "", "value"))
  output[[paste0(input_id, "_label")]] <- shiny::renderText({
    val <- input[[input_id]]
    if (is.null(val) || !(val %in% names(labels))) "" else labels[[val]]
  })
}
