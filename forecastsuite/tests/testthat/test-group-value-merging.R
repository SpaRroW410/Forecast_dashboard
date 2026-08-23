test_that("compute_group_value_map merges case/whitespace variants using the most frequent casing", {
  raw <- c("female", "Female", "female", "male", "Male", "Male", "Transgender", "female")
  m <- compute_group_value_map(raw, merge_case = TRUE)
  expect_setequal(m$raw, c("female", "Female", "male", "Male", "Transgender"))
  expect_equal(m$label[m$raw == "female"], "female")   # 3 occurrences beats Female's 1
  expect_equal(m$label[m$raw == "Female"], "female")
  expect_equal(m$label[m$raw == "male"], "Male")        # Male (2) beats male (1)
  expect_equal(m$label[m$raw == "Male"], "Male")
  expect_equal(m$label[m$raw == "Transgender"], "Transgender")
  expect_equal(length(unique(m$label)), 3)
})

test_that("compute_group_value_map with merge_case = FALSE keeps every raw value distinct", {
  raw <- c("female", "Female", "male")
  m <- compute_group_value_map(raw, merge_case = FALSE)
  expect_equal(m$label, m$raw)
  expect_equal(length(unique(m$label)), 3)
})

test_that("compute_group_value_map handles NA and an empty column", {
  expect_equal(nrow(compute_group_value_map(character(0))), 0)
  m <- compute_group_value_map(c("A", NA, "a", NA))
  expect_equal(nrow(m), 2)
})

test_that("the Import UI exposes the merge-case checkbox and relabel controls", {
  html <- as.character(build_import_tab_ui())
  expect_true(grepl("fs_group_merge_case", html, fixed = TRUE))
  expect_true(grepl("fs_group_map_table", html, fixed = TRUE))
  expect_true(grepl("fs_group_new_label", html, fixed = TRUE))
  expect_true(grepl("fs_group_apply_relabel", html, fixed = TRUE))
  expect_true(grepl("fs_group_reset_map", html, fixed = TRUE))
})

.merge_demo_data <- function() {
  set.seed(1)
  data.frame(
    Date = rep(seq.Date(as.Date("2021-01-01"), as.Date("2021-12-31"), by = "day"), 5),
    Sex = rep(c("female", "Female", "male", "Male", "Transgender"), each = 365),
    Cases = c(stats::rpois(365, 20), stats::rpois(365, 5), stats::rpois(365, 15),
              stats::rpois(365, 3), stats::rpois(365, 2))
  )
}

test_that("auto-merge (default on) collapses case-variant raw values into one group", {
  main <- .merge_demo_data()
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_merge_test_df", main, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_merge_test_df")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "Date", fs_value_col = "Cases")
    session$setInputs(fs_date_agg = "month")
    session$setInputs(fs_group_merge_case = TRUE)
    session$setInputs(fs_group_col = "Sex")

    gmap <- group_value_map()
    labels <- sort(unique(gmap$label))
    expect_setequal(labels, c("Female", "Male", "Transgender"))

    session$setInputs(fs_group_values = labels)
    session$setInputs(fs_finalize_data = 1)

    gs <- grouped_series()
    expect_setequal(names(gs), c("Female", "Male", "Transgender"))
    # the merged group's total equals both raw variants summed
    raw_female_total <- sum(main$Cases[main$Sex %in% c("female", "Female")])
    expect_equal(sum(gs[["Female"]]$y), raw_female_total)
    # effective_group_col() stays the semantic column name, not the
    # internal merged-label working column
    expect_equal(effective_group_col(), "Sex")
  })
  rm("fs_merge_test_df", envir = globalenv())
})

test_that("turning auto-merge off keeps every raw value as its own group", {
  main <- .merge_demo_data()
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_merge_test_df2", main, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_merge_test_df2")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "Date", fs_value_col = "Cases")
    session$setInputs(fs_date_agg = "month")
    session$setInputs(fs_group_merge_case = FALSE)
    session$setInputs(fs_group_col = "Sex")

    gmap <- group_value_map()
    expect_setequal(gmap$label, c("female", "Female", "male", "Male", "Transgender"))
  })
  rm("fs_merge_test_df2", envir = globalenv())
})

test_that("manually relabeling selected rows merges them into a custom label", {
  main <- .merge_demo_data()
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_merge_test_df3", main, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_merge_test_df3")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "Date", fs_value_col = "Cases")
    session$setInputs(fs_date_agg = "month")
    session$setInputs(fs_group_merge_case = TRUE)
    session$setInputs(fs_group_col = "Sex")

    gmap <- group_value_map()
    sel <- which(gmap$raw == "Transgender")
    session$setInputs(fs_group_map_table_rows_selected = sel)
    session$setInputs(fs_group_new_label = "Other")
    session$setInputs(fs_group_apply_relabel = 1)

    gmap2 <- group_value_map()
    expect_equal(gmap2$label[gmap2$raw == "Transgender"], "Other")
    # the other rows are untouched
    expect_equal(gmap2$label[gmap2$raw == "female"], "Female")

    session$setInputs(fs_group_values = sort(unique(gmap2$label)))
    session$setInputs(fs_finalize_data = 1)
    expect_true("Other" %in% names(grouped_series()))
    expect_false("Transgender" %in% names(grouped_series()))
  })
  rm("fs_merge_test_df3", envir = globalenv())
})

test_that("resetting the mapping discards manual relabels and reapplies the current auto-merge setting", {
  main <- .merge_demo_data()
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_merge_test_df4", main, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_merge_test_df4")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "Date", fs_value_col = "Cases")
    session$setInputs(fs_date_agg = "month")
    session$setInputs(fs_group_merge_case = TRUE)
    session$setInputs(fs_group_col = "Sex")

    gmap <- group_value_map()
    session$setInputs(fs_group_map_table_rows_selected = which(gmap$raw == "Transgender"))
    session$setInputs(fs_group_new_label = "Other")
    session$setInputs(fs_group_apply_relabel = 1)
    expect_true("Other" %in% group_value_map()$label)

    session$setInputs(fs_group_reset_map = 1)
    gmap_reset <- group_value_map()
    expect_false("Other" %in% gmap_reset$label)
    expect_setequal(unique(gmap_reset$label), c("Female", "Male", "Transgender"))
  })
  rm("fs_merge_test_df4", envir = globalenv())
})

test_that("the ungrouped path is unaffected by the merge-mapping feature", {
  df <- data.frame(when = as.Date("2024-01-01") + 0:29, val = 1:30)
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_merge_ungrouped_df", df, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_merge_ungrouped_df")
    session$setInputs(fs_load_env = 1)
    session$setInputs(fs_data_type = "agg")
    session$setInputs(fs_date_mode = "single", fs_date_col = "when", fs_value_col = "val")
    session$setInputs(fs_date_agg = "day")
    session$setInputs(fs_finalize_data = 1)

    expect_null(grouped_series())
    expect_equal(nrow(final_dataset()), 30)
    expect_null(group_value_map())
  })
  rm("fs_merge_ungrouped_df", envir = globalenv())
})
