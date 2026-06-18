test_that("fetch_by_query output type", {
  testthat::skip_if_offline()

  ozone_df <- fetch_by_query("organisation:/Land/Bayern/open.bydata AND Ozon")
  expect_s3_class(ozone_df, "tbl_df")
})

test_that("fetch_by_url output type", {
  testthat::skip_if_offline()

  ozone_df <- fetch_by_url("https://md.umwelt.info/search/all?query=(Ozon)+AND+organisation%3A%2FLand%2FBayern%2Fopen.bydata")
  expect_s3_class(ozone_df, "tbl_df")
})

test_that("fetch_by_url and fetch_by_query return consistent results", {
  testthat::skip_if_offline()

  df1 <- fetch_by_query("(Ozon) AND organisation:/Land/Bayern/open.bydata")
  df2 <- fetch_by_url("https://md.umwelt.info/search/all?query=(Ozon)+AND+organisation%3A%2FLand%2FBayern%2Fopen.bydata")

  expect_equal(df1, df2)
})

test_that("fetch_by_ids", {
  testthat::skip_if_offline()

  ids1 <- "uvk-be/-sen-uvk-umwelt-luft-luftqualitaet-"
  df1 <- fetch_by_ids(ids1)
  expect_s3_class(df1, "tbl_df")

  ids2 <- c(
    "uvk-be/-sen-uvk-umwelt-luft-luftqualitaet-",
    "lanuk-nrw/-publikationen-publikation-bericht-ueber-die-luftqualitaet-im-jahre-2014",
    "metaver-hb/7F0A29F5-ECBC-476D-9C99-DC1A6A8043D0"
  )
  df2 <- fetch_by_ids(ids2)
  expect_s3_class(df2, "tbl_df")
  expect_equal(dim(df2)[1], length(ids2))
})

test_that("fetch_facet_values ressource_type", {
  testthat::skip_if_offline()

  name <- "resource_type"
  expect_type(fetch_facet_values(name), "character")
})

test_that("fetch_facet_values error name", {
  testthat::skip_if_offline()

  name <- "organisations"
  expect_error(fetch_facet_values(name), "Names must be one of: type, topic, organisation, license, language and resource_type.")
})

test_that("fetch_by_url with single selected column", {
  testthat::skip_if_offline()

  url <- "https://md.umwelt.info/search/all?query=(Ozon)+AND+organisation%3A%2FLand%2FBayern%2Fopen.bydata"
  columns <- "id"
  expect_equal(colnames(fetch_by_url(url, columns)), columns)
})

test_that("fetch_by_url with multiple selected columns", {
  testthat::skip_if_offline()

  url <- "https://md.umwelt.info/search/all?query=(Ozon)+AND+organisation%3A%2FLand%2FBayern%2Fopen.bydata"
  columns <- c("id", "tags", "resources")
  expect_equal(colnames(fetch_by_url(url, columns)), columns)
})

test_that(".check_columns success", {
  testthat::skip_if_offline()

  # check for some columns
  columns <- c("id", "tags", "resources", "last_harvest")
  valid_colums <- .check_columns(columns)

  expect_equal(all(columns %in% valid_colums), TRUE)
})

test_that(".check_columns error", {
  testthat::skip_if_offline()

  columns <- c("id", "tags", "ressources", "last_harvest")

  expect_error(.check_columns(columns),
    regexp = "Invalid column(s): ressources",
    fixed = TRUE
  )
})

test_that(".get_column_req", {
  testthat::skip_if_offline()

  url <- "https://md.umwelt.info/search/all?query=Luftqualität"
  columns <- c("id", "tags", "resources")

  req <- httr2::request(url) |>
    httr2::req_url_query(format = "arrow_ipc")

  req <- .get_column_req(.check_columns(columns), req)
  expect_equal(req$url, "https://md.umwelt.info/search/all?query=Luftqualit%C3%A4t&format=arrow_ipc&columns=id&columns=tags&columns=resources")
})
