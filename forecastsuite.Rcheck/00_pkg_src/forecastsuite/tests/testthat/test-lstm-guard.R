test_that("lstm_available() reflects whether torch is installed", {
  expect_equal(lstm_available(), requireNamespace("torch", quietly = TRUE))
})

test_that("lstm fit fails with a clear, actionable message when torch is missing", {
  skip_if(requireNamespace("torch", quietly = TRUE), "torch is installed in this environment")
  m <- get_model("lstm")
  expect_error(
    m$fit(data.frame(ds = Sys.Date() - 30:1, y = rnorm(30))),
    "torch"
  )
})

test_that("library(forecastsuite) never errors even without torch", {
  # Loading the package must not fail just because an optional Suggests
  # dependency is absent -- only *calling* the lstm fit function should.
  expect_true(exists("get_model"))
  expect_no_error(get_model("lstm"))
})

test_that("the Model tab UI exposes LSTM hyperparameter controls", {
  html <- as.character(build_model_tab_ui())
  expect_true(grepl("fs_lstm_epochs", html, fixed = TRUE))
  expect_true(grepl("fs_lstm_hidden", html, fixed = TRUE))
  expect_true(grepl("fs_lstm_lookback", html, fixed = TRUE))
  expect_true(grepl("fs_lstm_lr", html, fixed = TRUE))
})

test_that("build_fit_args()/scalar_fit_args_for_code() pass the UI's LSTM inputs through", {
  train_df <- tibble::tibble(ds = Sys.Date() - 30:1, y = stats::rnorm(30))
  shiny::testServer(build_app_server, {
    session$setInputs(fs_model_choice = "lstm")
    session$setInputs(fs_lstm_epochs = 10, fs_lstm_hidden = 8, fs_lstm_lookback = 4, fs_lstm_lr = 0.05)

    args <- build_fit_args("lstm", train_df)
    expect_equal(args$epochs, 10)
    expect_equal(args$hidden_size, 8)
    expect_equal(args$lookback, 4)
    expect_equal(args$lr, 0.05)

    scalar_args <- scalar_fit_args_for_code("lstm")
    expect_equal(scalar_args, list(epochs = 10, hidden_size = 8, lookback = 4, lr = 0.05))
  })
})

test_that("restore_project_inputs() sends the right update message for each LSTM field", {
  # updateNumericInput() calls cannot be verified to reach input$x inside
  # shiny::testServer() -- there is no simulated client to echo the update
  # message back (same limitation documented for the other restore_*
  # fields in test-project-save-load.R). Verify the sendInputMessage()
  # payload directly instead, bypassing reactivity.
  captured <- list()
  fake_session <- structure(
    list(sendInputMessage = function(inputId, message) captured[[inputId]] <<- message),
    class = "ShinySession"
  )
  ui_inputs <- list(fs_lstm_epochs = 25, fs_lstm_hidden = 16, fs_lstm_lookback = 6, fs_lstm_lr = 0.02)
  restore_project_inputs(fake_session, list(ui_inputs = ui_inputs))

  expect_equal(captured$fs_lstm_epochs$value, "25")
  expect_equal(captured$fs_lstm_hidden$value, "16")
  expect_equal(captured$fs_lstm_lookback$value, "6")
  expect_equal(captured$fs_lstm_lr$value, "0.02")
})
