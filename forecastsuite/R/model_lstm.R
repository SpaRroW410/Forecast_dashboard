# LSTM adapter -- deep-learning forecaster backed by the `torch` R package
# (Suggests, not Imports; see DESCRIPTION). Isolated in its own file so no
# other part of the package needs to know or care whether torch is
# installed.
#
# *** IMPORTANT -- VERIFICATION STATUS ***
# This file's torch-dependent code (tensor construction, nn_module
# definition, training loop, recursive forecasting) was written and
# statically reviewed only. The sandbox that authored it has no CRAN
# access and torch is not apt-installable here, so none of this could be
# installed or executed. Treat it as "reviewed but unverified" until you
# install torch locally and run it yourself:
#   install.packages("torch"); torch::install_torch()
# Everything else in forecastsuite works without torch -- list_models()
# simply omits "lstm" until torch is available (see `requires = "torch"`
# in zzz_register_builtins.R).

lstm_available <- function() {
  requireNamespace("torch", quietly = TRUE)
}

.require_torch_or_stop <- function() {
  if (!lstm_available()) {
    stop(
      "The 'torch' package is required for LSTM forecasting. Install it with:\n",
      "  install.packages(\"torch\"); torch::install_torch()\n",
      "LSTM is optional -- every other model in forecastsuite works without it.",
      call. = FALSE
    )
  }
}

# Returns the torch namespace for runtime use, e.g. th$torch_tensor(...).
#
# Deliberately NOT written as static `torch::fn()` calls: torch is a
# Suggests dependency, so it is normally absent at install time, and R's
# byte-compiler attempts to resolve `pkg::name` references while compiling.
# Looking the namespace up at runtime instead leaves nothing for the
# compiler to resolve, so this file compiles cleanly whether or not torch
# is installed. Callers must invoke .require_torch_or_stop() first (this
# does so itself), so a missing torch still produces the friendly error
# above rather than an obscure namespace failure.
.torch_ns <- function() {
  .require_torch_or_stop()
  asNamespace("torch")
}

.lstm_fit <- function(train_df, date_agg = "day", epochs = 50, hidden_size = 32,
                       lookback = 12, lr = 0.01, ...) {
  th <- .torch_ns()

  y <- train_df$y
  y <- zoo::na.approx(y, na.rm = FALSE)
  y[is.na(y)] <- mean(y, na.rm = TRUE)

  if (length(y) <= lookback + 1) {
    stop("Not enough training rows for LSTM with lookback = ", lookback,
         " (need more than ", lookback + 1, " observations).", call. = FALSE)
  }

  y_mean <- mean(y)
  y_sd <- stats::sd(y)
  if (!is.finite(y_sd) || y_sd == 0) y_sd <- 1
  y_scaled <- (y - y_mean) / y_sd

  n <- length(y_scaled)
  x_list <- lapply(seq_len(n - lookback), function(i) y_scaled[i:(i + lookback - 1)])
  y_list <- y_scaled[(lookback + 1):n]

  x_arr <- th$torch_tensor(do.call(rbind, x_list), dtype = th$torch_float())$unsqueeze(3)
  y_arr <- th$torch_tensor(matrix(y_list, ncol = 1), dtype = th$torch_float())

  lstm_module <- th$nn_module(
    "forecastsuite_lstm",
    initialize = function(hidden_size) {
      self$lstm <- th$nn_lstm(input_size = 1, hidden_size = hidden_size, batch_first = TRUE)
      self$fc <- th$nn_linear(hidden_size, 1)
    },
    forward = function(x) {
      out <- self$lstm(x)
      last_hidden <- out[[1]][, -1, ]
      self$fc(last_hidden)
    }
  )

  net <- lstm_module(hidden_size = hidden_size)
  optimizer <- th$optim_adam(net$parameters, lr = lr)
  loss_fn <- th$nn_mse_loss()

  net$train()
  for (epoch in seq_len(epochs)) {
    optimizer$zero_grad()
    pred <- net(x_arr)
    loss <- loss_fn(pred, y_arr)
    loss$backward()
    optimizer$step()
  }

  list(
    net = net,
    y_mean = y_mean,
    y_sd = y_sd,
    lookback = lookback,
    last_window = utils::tail(y_scaled, lookback)
  )
}

.lstm_forecast <- function(model, h, ...) {
  th <- .torch_ns()

  window <- model$last_window
  preds_scaled <- numeric(h)
  net <- model$net
  net$eval()

  th$with_no_grad({
    for (i in seq_len(h)) {
      x_in <- th$torch_tensor(matrix(window, nrow = 1), dtype = th$torch_float())$unsqueeze(3)
      pred <- net(x_in)
      pred_val <- as.numeric(pred$squeeze())
      preds_scaled[i] <- pred_val
      window <- c(window[-1], pred_val)
    }
  })

  list(mean = preds_scaled * model$y_sd + model$y_mean)
}

.lstm_to_tibble <- function(fc_obj, test_df) {
  h <- length(fc_obj$mean)
  n <- min(h, nrow(test_df))
  tibble::tibble(
    ds   = test_df$ds[seq_len(n)],
    yhat = as.numeric(fc_obj$mean)[seq_len(n)]
  )
}
