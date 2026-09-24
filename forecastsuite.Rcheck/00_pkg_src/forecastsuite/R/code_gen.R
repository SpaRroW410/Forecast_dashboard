# Generates a standalone, runnable R snippet mirroring exactly what a
# "Fit & Forecast" / "Compare Selected Models" click just executed --
# the esquisse-style "show the code" panel for the Model tab
# (app_ui.R/app_server.R). Data arguments (train_df/test_df/holidays_df)
# are referenced as bare variable names rather than deparsed inline, since
# deparsing a whole data.frame would be enormous and unreadable; every
# other argument is deparsed as a literal so it reflects the actual UI
# state at fit time.

# Small, deliberately non-parser syntax highlighter for the Show Code
# panel -- regex-based, not a real R tokenizer, so it can mis-highlight
# edge cases (e.g. a keyword-looking word inside an unusual string). That's
# an accepted tradeoff for a generated snippet from a small fixed template,
# in exchange for zero new dependencies (no bundling a JS highlighting
# library as a local asset for one cosmetic feature).
.fs_code_keywords <- c("function", "if", "else", "for", "while", "repeat", "break",
                        "next", "return", "TRUE", "FALSE", "NULL", "NA", "library",
                        "Inf", "NaN")

.fs_html_escape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x
}

highlight_r_code <- function(code) {
  if (is.null(code) || length(code) != 1 || !nzchar(code)) return("")

  kw_pattern <- paste0("\\b(", paste(.fs_code_keywords, collapse = "|"), ")\\b")
  token_pattern <- paste0(
    "(#[^\n]*)",                                          # comment
    "|('(?:[^'\\\\]|\\\\.)*'|\"(?:[^\"\\\\]|\\\\.)*\")",  # string
    "|", kw_pattern,                                       # keyword
    "|\\b([0-9]+\\.?[0-9]*(?:[eE][-+]?[0-9]+)?L?)\\b"      # number
  )

  highlight_line <- function(line) {
    m <- gregexpr(token_pattern, line, perl = TRUE)
    matches <- regmatches(line, m)[[1]]
    if (length(matches) == 0) return(.fs_html_escape(line))

    starts <- as.integer(m[[1]])
    lens <- attr(m[[1]], "match.length")
    out <- character(0)
    pos <- 1L
    for (i in seq_along(matches)) {
      s <- starts[i]; l <- lens[i]
      if (s > pos) out <- c(out, .fs_html_escape(substr(line, pos, s - 1)))
      tok <- matches[i]
      cls <- if (startsWith(tok, "#")) {
        "hl-comment"
      } else if (startsWith(tok, "'") || startsWith(tok, "\"")) {
        "hl-str"
      } else if (grepl("^[0-9]", tok)) {
        "hl-num"
      } else {
        "hl-kw"
      }
      out <- c(out, sprintf('<span class="%s">%s</span>', cls, .fs_html_escape(tok)))
      pos <- s + l
    }
    if (pos <= nchar(line)) out <- c(out, .fs_html_escape(substr(line, pos, nchar(line))))
    paste(out, collapse = "")
  }

  lines <- strsplit(code, "\n", fixed = TRUE)[[1]]
  highlighted <- vapply(lines, highlight_line, character(1), USE.NAMES = FALSE)
  paste0('<pre class="fs-code">', paste(highlighted, collapse = "\n"), "</pre>")
}

.deparse_arg_lines <- function(args_list) {
  if (length(args_list) == 0) return(character(0))
  vapply(names(args_list), function(nm) {
    sprintf("%s = %s", nm, deparse(args_list[[nm]], width.cutoff = 500L))
  }, character(1))
}

build_fit_code <- function(model_key, date_agg, scalar_args = list(),
                            uses_holidays = FALSE, horizon, group_label = NULL) {
  arg_lines <- c(
    "train_df = train_df",
    sprintf("date_agg = %s", deparse(date_agg)),
    if (uses_holidays) "holidays_df = holidays_df",
    .deparse_arg_lines(scalar_args)
  )

  fit_call <- sprintf("fit_obj <- model$fit(\n  %s\n)", paste(arg_lines, collapse = ",\n  "))

  plot_lines <- if (identical(model_key, "prophet")) {
    "plot_forecast_generic(fc_raw, train_df = train_df, model_obj = fit_obj, show_trend = TRUE)"
  } else {
    c(
      "# model$annotate(fit_obj) returns e.g. \"ARIMA(2,1,1)\" for arima/sarima",
      "plot_forecast_generic(fc_tib, train_df = train_df, subtitle = model$annotate(fit_obj))"
    )
  }

  lines <- c(
    "library(forecastsuite)",
    "",
    if (!is.null(group_label)) sprintf("# Fit for group: %s", group_label),
    "# train_df / test_df: your finalized dataset's train/test split (ds, y columns)",
    if (uses_holidays) "# holidays_df: holidays configured on the Holidays tab (NULL if none)",
    "",
    sprintf('model <- get_model("%s")', model_key),
    fit_call,
    sprintf("fc_raw  <- model$forecast(fit_obj, h = %s)", deparse(horizon)),
    "fc_tib  <- model$to_tibble(fc_raw, test_df)",
    "",
    "safe_compute_metrics(fc_tib, test_df, label = model$label)",
    "",
    plot_lines
  )

  paste(lines, collapse = "\n")
}

build_comparison_code <- function(model_keys, date_agg, horizon, group_label = NULL) {
  keys_literal <- paste(sprintf('"%s"', model_keys), collapse = ", ")

  lines <- c(
    "library(forecastsuite)",
    "",
    if (!is.null(group_label)) sprintf("# Comparing models for group: %s", group_label),
    "# train_df / test_df: your finalized dataset's train/test split (ds, y columns)",
    "",
    sprintf("model_keys <- c(%s)", keys_literal),
    "",
    "results <- lapply(model_keys, function(key) {",
    "  model   <- get_model(key)",
    sprintf("  fit_obj <- model$fit(train_df, date_agg = %s)", deparse(date_agg)),
    sprintf("  fc_raw  <- model$forecast(fit_obj, h = %s)", deparse(horizon)),
    "  fc_tib  <- model$to_tibble(fc_raw, test_df)",
    "  safe_compute_metrics(fc_tib, test_df, label = model$label)",
    "})",
    "",
    "comparison <- dplyr::bind_rows(results)"
  )

  paste(lines, collapse = "\n")
}

# One model, fit across every included group -- the generated-code
# counterpart of the fs_fit_btn observer's grouped branch (R/app_server.R).
build_fit_code_grouped <- function(model_key, date_agg, scalar_args = list(),
                                    uses_holidays = FALSE, horizon, group_col, groups) {
  arg_lines <- c(
    "train_df = train_df",
    sprintf("date_agg = %s", deparse(date_agg)),
    if (uses_holidays) "holidays_df = holidays_df",
    .deparse_arg_lines(scalar_args)
  )
  fit_call <- sprintf("  fit_obj <- model$fit(\n    %s\n  )", paste(arg_lines, collapse = ",\n    "))
  groups_literal <- paste(sprintf('"%s"', groups), collapse = ", ")

  lines <- c(
    "library(forecastsuite)",
    "",
    sprintf("# groups: split your finalized dataset by '%s', e.g.:", group_col),
    sprintf('# groups <- split_by_group(dataset, "%s")', group_col),
    if (uses_holidays) "# holidays_df: holidays configured on the Holidays tab (NULL if none)",
    "",
    sprintf('model <- get_model("%s")', model_key),
    sprintf("fit_groups <- c(%s)", groups_literal),
    "",
    "results <- lapply(fit_groups, function(g) {",
    "  df <- groups[[g]]",
    "  test_cutoff <- lubridate::`%m-%`(max(df$ds), months(test_months))  # same cutoff as the Model tab",
    "  train_df <- df[df$ds <= test_cutoff, ]",
    "  test_df  <- df[df$ds >  test_cutoff, ]",
    fit_call,
    sprintf("  fc_raw  <- model$forecast(fit_obj, h = %s)", deparse(horizon)),
    "  fc_tib  <- model$to_tibble(fc_raw, test_df)",
    "  list(group = g, fit = fit_obj, forecast = fc_tib,",
    "       metrics = safe_compute_metrics(fc_tib, test_df, label = g))",
    "})",
    "names(results) <- fit_groups",
    "",
    "plot_group_overlay(",
    "  lapply(results, `[[`, \"forecast\"),",
    "  lapply(fit_groups, function(g) groups[[g]]) |> stats::setNames(fit_groups)",
    ")"
  )

  paste(lines, collapse = "\n")
}
