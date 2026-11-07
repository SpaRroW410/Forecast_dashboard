# User feedback and logging helpers for the hosted app.
#
# app_log(): one line per key event on stderr, which Posit Connect Cloud
# captures in the app's log. Prefixed and timestamped so a deployment log can
# be searched ("[forecast-dashboard") and read without the code open.
#
# notify_unless(): replaces silent req() guards on buttons. req() quietly
# does nothing when a precondition fails, so a click on e.g. "Generate
# Evaluation Metrics" before any forecast exists looked broken. This shows
# the user what's missing instead, and returns FALSE so the caller can return().

app_log <- function(..., session = NULL) {
  token <- if (!is.null(session) && !is.null(session$token)) substr(session$token, 1, 6) else "app"
  message(sprintf("[forecast-dashboard %s %s] %s",
                  format(Sys.time(), "%Y-%m-%d %H:%M:%S"), token, paste0(...)))
}

notify_unless <- function(ok, msg, type = "warning", duration = 8) {
  ok <- isTRUE(ok)
  if (!ok) showNotification(msg, type = type, duration = duration)
  ok
}

# Runs `expr`; on error, shows `what` plus the error message to the user, logs
# it, and returns NULL instead of letting the error end the session.
try_notify <- function(expr, what, session = NULL) {
  tryCatch(expr, error = function(e) {
    app_log("ERROR ", what, ": ", conditionMessage(e), session = session)
    showNotification(paste0("❌ ", what, ": ", conditionMessage(e)), type = "error", duration = NULL)
    NULL
  })
}

seconds_since <- function(t0) round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1)

# Logged once at start-up, so version skew (e.g. rstan vs StanHeaders) and
# locale problems are visible in the deployment log.
log_startup_environment <- function() {
  pkgs <- c("shiny", "bslib", "prophet", "rstan", "StanHeaders", "forecast", "datamods")
  versions <- vapply(pkgs, function(p) tryCatch(as.character(utils::packageVersion(p)), error = function(e) "missing"),
                     character(1))
  app_log("start-up: ", R.version.string, "; LC_CTYPE=", Sys.getlocale("LC_CTYPE"),
          "; UTF-8=", isTRUE(l10n_info()[["UTF-8"]]), "; ",
          paste(sprintf("%s %s", pkgs, versions), collapse = ", "))
}
