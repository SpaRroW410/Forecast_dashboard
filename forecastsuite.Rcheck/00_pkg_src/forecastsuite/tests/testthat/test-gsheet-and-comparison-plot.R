test_that("googlesheet_csv_url handles the URL shapes people actually paste", {
  id <- "1AbC_def-123"
  base <- paste0("https://docs.google.com/spreadsheets/d/", id, "/export?format=csv")

  expect_equal(googlesheet_csv_url(paste0("https://docs.google.com/spreadsheets/d/", id, "/edit#gid=456")),
               paste0(base, "&gid=456"))
  expect_equal(googlesheet_csv_url(paste0("https://docs.google.com/spreadsheets/d/", id, "/edit?usp=sharing")),
               base)
  expect_equal(googlesheet_csv_url(paste0("https://docs.google.com/spreadsheets/d/", id)), base)

  bare <- "1AbCdefGHIjklMNOpqrsTUVwxyz1234567890"
  expect_equal(googlesheet_csv_url(bare),
               paste0("https://docs.google.com/spreadsheets/d/", bare, "/export?format=csv"))
})

test_that("an explicit gid overrides one embedded in the URL", {
  url <- "https://docs.google.com/spreadsheets/d/1AbC_def-123/edit#gid=456"
  expect_match(googlesheet_csv_url(url, gid = "999"), "gid=999$")
  expect_match(googlesheet_csv_url(url, gid = ""), "gid=456$")
})

test_that("googlesheet_csv_url rejects input with no spreadsheet id", {
  expect_error(googlesheet_csv_url("https://example.com/foo"), "Could not find a spreadsheet ID")
  expect_error(googlesheet_csv_url(""), "Provide a Google Sheets URL")
})

test_that("plot_model_comparison overlays several models and tolerates gaps", {
  ds <- Sys.Date() + 1:10
  forecasts <- list(
    ARIMA = tibble::tibble(ds = ds, yhat = 1:10),
    ETS   = tibble::tibble(ds = ds, yhat = (1:10) * 1.1),
    Broken = NULL
  )
  train <- tibble::tibble(ds = Sys.Date() - 10:1, y = stats::rnorm(10))

  p <- plot_model_comparison(forecasts, train_df = train)
  expect_s3_class(p, "plotly")

  # a failed model contributing nothing must not break the others
  expect_s3_class(plot_model_comparison(forecasts["ARIMA"]), "plotly")
  expect_error(plot_model_comparison(list(Broken = NULL)), "No forecasts")
})

test_that("comparing models stores per-model forecasts and renders a plot", {
  path <- tempfile(fileext = ".csv")
  set.seed(11)
  n <- 220
  utils::write.csv(data.frame(
    date  = seq.Date(as.Date("2022-01-01"), by = "day", length.out = n),
    value = 100 + (1:n) * 0.03 + 8 * sin(2 * pi * (1:n) / 7) + stats::rnorm(n, 0, 3)
  ), path, row.names = FALSE)

  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "file")
    session$setInputs(fs_file = list(datapath = path, name = "d.csv"))
    session$setInputs(fs_date_mode = "single", fs_date_col = "date",
                       fs_value_col = "value", fs_date_agg = "day")
    session$setInputs(fs_finalize_data = 1)
    session$setInputs(fs_finalize_holidays = 1)
    session$setInputs(fs_horizon_months = 3, fs_test_months = 2, fs_arima_mode = "auto")

    session$setInputs(fs_compare_choices = c("arima", "ets"))
    session$setInputs(fs_compare_btn = 1)

    fcs <- comparison_forecasts()
    expect_equal(length(fcs), 2)
    expect_true(all(vapply(fcs, function(f) all(c("ds", "yhat") %in% names(f)), logical(1))))
    expect_false(is.null(comparison_train()))
    expect_no_error(output$fs_comparison_plot)
  })
})

test_that("the UI exposes the Google Sheet source and the comparison plot", {
  html <- as.character(build_app_ui())
  expect_true(grepl("fs_gsheet_url", html, fixed = TRUE))
  expect_true(grepl("Google Sheet", html, fixed = TRUE))
  expect_true(grepl("fs_comparison_plot", html, fixed = TRUE))
})
