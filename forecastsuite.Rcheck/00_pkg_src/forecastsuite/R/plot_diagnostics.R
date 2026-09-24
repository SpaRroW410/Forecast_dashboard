# Plotly renderers for R/diagnostics.R's pure functions. Same
# plot_ly()/layout() idiom and color palette as R/plot_generic.R -- every
# function here takes a pre-computed tibble, exactly like
# plot_forecast_generic()/plot_group_overlay() do, so the server layer stays
# a thin "compute then render" pair for each output.

plot_residuals <- function(residuals_df, title = "Residuals") {
  if (nrow(residuals_df) == 0) stop("No residuals to plot.", call. = FALSE)

  plotly::plot_ly(data = residuals_df, x = ~ds, y = ~resid,
                   type = "scatter", mode = "lines+markers",
                   line = list(color = "#d95f02"),
                   marker = list(color = "#d95f02", size = 5)) |>
    plotly::layout(
      title = title,
      xaxis = list(title = "Date"),
      yaxis = list(title = "Residual (actual - forecast)"),
      shapes = list(list(type = "line", x0 = 0, x1 = 1, xref = "paper", y0 = 0, y1 = 0,
                          line = list(color = "#666666", dash = "dot", width = 1))),
      hovermode = "x unified"
    )
}

plot_residual_acf <- function(acf_df, ci = NA_real_, title = "Residual ACF") {
  if (nrow(acf_df) == 0) stop("No ACF values to plot.", call. = FALSE)

  shapes <- if (!is.na(ci)) {
    list(
      list(type = "line", x0 = 0, x1 = 1, xref = "paper", y0 = ci, y1 = ci,
           line = list(color = "#666666", dash = "dash", width = 1)),
      list(type = "line", x0 = 0, x1 = 1, xref = "paper", y0 = -ci, y1 = -ci,
           line = list(color = "#666666", dash = "dash", width = 1))
    )
  } else {
    list()
  }

  plotly::plot_ly(data = acf_df, x = ~lag, y = ~acf, type = "bar",
                   marker = list(color = "#7570b3")) |>
    plotly::layout(title = title, xaxis = list(title = "Lag"), yaxis = list(title = "ACF"),
                   shapes = shapes)
}

# Three stacked, x-linked panels -- observed+trend, seasonal, remainder --
# the classic STL plot shape.
plot_decomposition <- function(decomp_tbl, title = "Seasonal Decomposition") {
  if (nrow(decomp_tbl) == 0) stop("No decomposition to plot.", call. = FALSE)

  p_obs <- plotly::plot_ly(data = decomp_tbl, x = ~ds) |>
    plotly::add_lines(y = ~observed, name = "Observed", line = list(color = "#1b9e77")) |>
    plotly::add_lines(y = ~trend, name = "Trend", line = list(color = "#7570b3", dash = "dot")) |>
    plotly::layout(yaxis = list(title = "Observed / Trend"))

  p_season <- plotly::plot_ly(data = decomp_tbl, x = ~ds, y = ~seasonal,
                               type = "scatter", mode = "lines", name = "Seasonal",
                               line = list(color = "#d95f02")) |>
    plotly::layout(yaxis = list(title = "Seasonal"))

  p_rem <- plotly::plot_ly(data = decomp_tbl, x = ~ds, y = ~remainder,
                            type = "scatter", mode = "lines", name = "Remainder",
                            line = list(color = "#e7298a")) |>
    plotly::layout(yaxis = list(title = "Remainder"))

  plotly::subplot(p_obs, p_season, p_rem, nrows = 3, shareX = TRUE, titleY = TRUE) |>
    plotly::layout(title = title, hovermode = "x unified")
}

# cor_tbl: tidy group_a/group_b/correlation (upper triangle only, as
# returned by diagnostics.R::group_correlation_matrix()) -- symmetrized
# here into a full matrix (diagonal = 1) for the heatmap.
plot_group_correlation <- function(cor_tbl, title = "Group Correlation") {
  if (nrow(cor_tbl) == 0) stop("No correlations to plot.", call. = FALSE)

  groups <- sort(unique(c(cor_tbl$group_a, cor_tbl$group_b)))
  z <- matrix(1, nrow = length(groups), ncol = length(groups),
              dimnames = list(groups, groups))
  for (i in seq_len(nrow(cor_tbl))) {
    a <- cor_tbl$group_a[i]; b <- cor_tbl$group_b[i]; v <- cor_tbl$correlation[i]
    z[a, b] <- v
    z[b, a] <- v
  }

  plotly::plot_ly(
    x = groups, y = groups, z = z, type = "heatmap",
    colorscale = list(list(0, "#d95f02"), list(0.5, "#f4ecd8"), list(1, "#1b9e77")),
    zmin = -1, zmax = 1
  ) |>
    plotly::layout(title = title, xaxis = list(title = ""), yaxis = list(title = ""))
}
