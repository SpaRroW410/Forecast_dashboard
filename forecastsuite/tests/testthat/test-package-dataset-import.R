test_that("the Import UI exposes the package-dataset sub-source controls", {
  html <- as.character(build_import_tab_ui())
  expect_true(grepl("fs_env_kind", html, fixed = TRUE))
  expect_true(grepl("fs_pkg_name", html, fixed = TRUE))
  expect_true(grepl("fs_pkg_dataset", html, fixed = TRUE))
})

test_that(".pkg_dataset_loadable_name() strips the parenthetical display title and picks the first name", {
  shiny::testServer(build_app_server, {
    expect_equal(.pkg_dataset_loadable_name("iris"), "iris")
    expect_equal(.pkg_dataset_loadable_name("BJsales.lead (BJsales)"), "BJsales.lead")
    expect_equal(.pkg_dataset_loadable_name("beaver1, beaver2 (beavers)"), "beaver1")
  })
})

test_that("choosing a package populates its dataset list, and Load reads a real dataset into raw_data()", {
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    session$setInputs(fs_env_kind = "package")
    session$setInputs(fs_pkg_name = "datasets")

    idx <- pkg_dataset_index()
    expect_false(is.null(idx))
    expect_true("datasets" %in% idx[, "Package"])

    session$setInputs(fs_pkg_dataset = "iris")
    session$setInputs(fs_load_env = 1)

    df <- raw_data()
    expect_false(is.null(df))
    expect_equal(nrow(df), 150)
    expect_true("Species" %in% names(df))
  })
})

test_that("the default (unset fs_env_kind) still loads from the global environment, unchanged", {
  df_main <- data.frame(when = as.Date("2024-01-01") + 0:9, val = 1:10)
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    assign("fs_pkgimport_globalenv_df", df_main, envir = globalenv())
    session$setInputs(fs_env_obj = "fs_pkgimport_globalenv_df")
    session$setInputs(fs_load_env = 1)

    df <- raw_data()
    expect_equal(nrow(df), 10)
    expect_equal(names(df), c("when", "val"))
  })
  rm("fs_pkgimport_globalenv_df", envir = globalenv())
})

test_that("a non-data-frame package object is rejected with a clear notification, not an error", {
  shiny::testServer(build_app_server, {
    session$setInputs(fs_import_source = "env")
    session$setInputs(fs_env_kind = "package")
    session$setInputs(fs_pkg_name = "datasets")
    session$setInputs(fs_pkg_dataset = "AirPassengers")  # a ts object, not a data.frame
    expect_no_error(session$setInputs(fs_load_env = 1))
  })
})
