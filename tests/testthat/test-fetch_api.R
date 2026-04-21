test_that("fetch_api_output_type", {
  testthat::skip_if_offline()

  ozone_df <- fetch_by_query("organisation:/Land/Bayern/open.bydata AND Ozon")
  expect_s3_class(ozone_df, "data.frame")
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
  expect_type(df1, "list")

  ids2 <- c(
    "uvk-be/-sen-uvk-umwelt-luft-luftqualitaet-",
    "lanuk-nrw/-publikationen-publikation-bericht-ueber-die-luftqualitaet-im-jahre-2014",
    "metaver-hb/7F0A29F5-ECBC-476D-9C99-DC1A6A8043D0"
  )
  df2 <- fetch_by_ids(ids2)
  expect_type(df2, "list")
  expect_equal(length(df2), length(ids2))
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
