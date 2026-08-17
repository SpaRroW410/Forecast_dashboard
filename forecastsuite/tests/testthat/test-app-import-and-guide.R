test_that("the app UI exposes all four import sources and the Model Guide tab", {
  html <- as.character(build_app_ui())
  for (id in c("fs_import_source", "fs_file", "fs_env_obj", "fs_url", "fs_paste")) {
    expect_true(grepl(id, html, fixed = TRUE), info = id)
  }
  expect_true(grepl("Model Guide", html, fixed = TRUE))
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
