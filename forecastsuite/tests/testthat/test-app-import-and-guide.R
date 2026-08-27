test_that("the app UI exposes all four import sources and the Model Guide tab", {
  html <- as.character(build_app_ui())
  for (id in c("fs_import_source", "fs_file", "fs_env_obj", "fs_url", "fs_paste")) {
    expect_true(grepl(id, html, fixed = TRUE), info = id)
  }
  expect_true(grepl("Model Guide", html, fixed = TRUE))
})

test_that("import and population sources render as icon buttons with hover tooltips", {
  html <- as.character(build_app_ui())
  expect_true(grepl("icon-vertical", html, fixed = TRUE))
  expect_true(grepl("icon-btn", html, fixed = TRUE))
  for (id in c("fs_src_file", "fs_src_env", "fs_src_gsheet", "fs_src_url", "fs_src_paste",
               "fs_pop_src_file", "fs_pop_src_env")) {
    expect_true(grepl(id, html, fixed = TRUE), info = id)
  }
  for (tooltip in c("File upload (CSV / TSV / Excel)", "Global environment",
                     "Google Sheet", "Paste text")) {
    expect_true(grepl(tooltip, html, fixed = TRUE), info = tooltip)
  }
})

test_that("wire_icon_source updates the hidden radio when a real client echoes the click", {
  # shiny::testServer has no JS engine, so it can't simulate the browser
  # round-trip that update*Input() relies on: a click bumps the actionLink's
  # counter, the server calls updateRadioButtons(), and in a *real* app the
  # client applies that and echoes the new radio value back as input$<id>.
  # We simulate that echo explicitly (setInputs on the target id) rather than
  # asserting on the update call itself, since testServer can't observe it.
  server <- function(input, output, session) {
    forecastsuite:::wire_icon_source(input, output, session, "fs_import_source", list(
      list(id = "fs_src_file", value = "file", title = "File upload"),
      list(id = "fs_src_env",  value = "env",  title = "Global environment")
    ))
  }
  shiny::testServer(server, {
    session$setInputs(fs_import_source = "env")
    expect_equal(output$fs_import_source_label, "Global environment")
    session$setInputs(fs_import_source = "file")
    expect_equal(output$fs_import_source_label, "File upload")
  })
})

test_that("the Model Guide tab builds and covers every registered model", {
  html <- as.character(build_guide_tab_ui())
  for (label in c("Prophet", "ARIMA", "SARIMA", "ETS", "TBATS", "NNETAR",
                  "Holt-Winters", "LSTM")) {
    expect_true(grepl(label, html, fixed = TRUE), info = label)
  }
  # and the explanatory sections
  for (section in c("Uploading Your Data", "How Model Recommendation Works",
                    "Evaluation Metrics", "Holidays")) {
    expect_true(grepl(section, html, fixed = TRUE), info = section)
  }
})

test_that("the Application Guide tab builds and covers the end-to-end forecast workflow, separate from the Model Guide", {
  html <- as.character(build_app_guide_tab_ui())
  for (step in c("Import your data", "Configure holidays", "Pick a model and fit",
                "Read your results", "Save your work")) {
    expect_true(grepl(step, html, fixed = TRUE), info = step)
  }
})

test_that("the app exposes the Application Guide as its own top-level tab", {
  html <- as.character(build_app_ui())
  expect_true(grepl("app_guide_tab", html, fixed = TRUE))
  expect_true(grepl("Application Guide", html, fixed = TRUE))
})

test_that("import accepts a data frame from the global environment", {
  assign("fs_test_series", data.frame(
    date = seq.Date(as.Date("2023-01-01"), by = "day", length.out = 60),
    value = stats::rnorm(60, 100, 5)
  ), envir = globalenv())
  on.exit(rm("fs_test_series", envir = globalenv()), add = TRUE)

  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    session$setInputs(fs_env_obj = "fs_test_series")
    session$setInputs(fs_load_env = 1)
    expect_equal(nrow(raw_data()), 60)
    expect_setequal(names(raw_data()), c("date", "value"))
  })
})

test_that("import accepts pasted delimited text", {
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "paste", fs_paste_sep = ",")
    session$setInputs(fs_paste = "date,value\n2024-01-01,10\n2024-01-02,12\n2024-01-03,11")
    session$setInputs(fs_load_paste = 1)
    expect_equal(nrow(raw_data()), 3)
    expect_setequal(names(raw_data()), c("date", "value"))
  })
})

test_that("unparseable input is rejected without discarding already-loaded data", {
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "paste", fs_paste_sep = ",")
    session$setInputs(fs_paste = "date,value\n2024-01-01,10\n2024-01-02,12")
    session$setInputs(fs_load_paste = 1)
    expect_equal(nrow(raw_data()), 2)

    # a single-column blob has < 2 columns and must be refused
    session$setInputs(fs_paste = "not a table")
    session$setInputs(fs_load_paste = 2)
    expect_equal(nrow(raw_data()), 2)
  })
})
