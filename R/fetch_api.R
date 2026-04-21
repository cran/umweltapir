#' Fetch data from umwelt.info
#'
#' These functions allow you to retrieve datasets from the umwelt.info metadata
#' search API either by providing a search query or a complete URL.
#'
#' @param url A character string containing the full API request URL.
#' @param query A character vector containing the search query (e.g., "Ozon").
#' @param ids A list of character strings containing the ID(s) of datasets.
#' @param name A character string containing the name of the facet for which all possible
#'   values will be returned (list). These can be used to create a new query.
#'   Possible values: type, topic, organisation, license, language and resource_type.
#'   Default value: type.
#' @param language A string to determine the language of the search results.
#'   Possible values: de and en. Default: de (German).
#' @param columns Either a vector of strings containing the selected columns or "resource_only" as a shortcut to select the columns "source", "id", "resources", "title" and "quality"
#'
#' @returns A dataframe containing the dataset entries. Returns an empty
#'   dataframe if no results are found.
#'
#' @name fetch_data
#' @examples
#' # Example 1: Fetching by a direct URL
#' if (interactive()) {
#'   api_url <- "https://md.umwelt.info/search/all?query=Luftqualität"
#'   result_list <- fetch_by_url(api_url)
#' }
#'
#' # Example 2: Fetching by query string
#' # For background how to build a query see https://md.umwelt.info/swagger-ui/#/search/text_search
#' # If you want to know which facet values exist for a certain facet, you can use
#' # fetch_facet_values (see example 5).
#' if (interactive()) {
#'   result_list <- fetch_by_query("(Ozon) AND organisation:/Land/Bayern/open.bydata")
#' }
#'
#' # Example 3: Select subset of columns and unnest columns (here the column "resources" is unnested
#' # into its subcolums "type", "url", "description", "direct_link" and "primary_content") and in a
#' # second step "type" is further unnested into "path" and "label"
#' if (interactive()) {
#'   result_list <- fetch_by_query("(Ozon) AND organisation:/Land/Bayern/open.bydata")
#'   colnames(result_list) # columns before unnesting
#'   result_list <- result_list |>
#'     tidyr::unnest(col = c("source")) |>
#'     (\(df) df[, c("source", "id", "resources", "title", "quality"), drop = FALSE])() |>
#'     tidyr::unnest(col = c("resources")) |>
#'     tidyr::unnest(col = c("type"))
#'   colnames(result_list) # columns after unnesting)
#' }
#'
#' # Example 4: Fetching by a list of dataset IDs. This can e.g. be useful for downloading resources.
#' # After using preview_resources you can select a subset of from the preview list using
#' # fetch_by_ids() and forward it as input to download_resources().
#' ids <- c(
#'   "uvk-be/-sen-uvk-umwelt-luft-luftqualitaet-",
#'   "lanuk-nrw/-publikationen-publikation-bericht-ueber-die-luftqualitaet-im-jahre-2014",
#'   "metaver-hb/7F0A29F5-ECBC-476D-9C99-DC1A6A8043D0"
#' )
#' datasets <- fetch_by_ids(ids)
#' for (dataset in datasets) {
#'   print(dataset$title)
#' }
#'
#' # Example 5: Fetching all possible values for the facet name organisation. This can be e.g. useful
#' # if you want to restrict the results to certain organisations when build your own query,
#' # so you know which organisations are available.
#' name <- "organisation"
#' organisations <- fetch_facet_values(name)
#' head(organisations)
#'
#' # Example 7: Fetch multiple facets at the same time
#' # If you want to fetch more than one facet, the easiest way is to use fetch_by_query() for this.
#' if (interactive()) {result_list  <- fetch_by_query(
#'  query =
#'  "organisation:/Bund/Destatis OR organisation:'/Land/Statistische Ämter des Bundes und der Länder'")
#' }
NULL

#' @rdname fetch_data
#' @export
fetch_by_query <- function(query, language = "de", columns = NULL) {
  if (!language %in% c("de", "en")) {
    stop("Language must either be \"de\" or \"en\".")
  }
  httr2::request("https://md.umwelt.info/search/all") |>
    httr2::req_url_query(query = query, language = language) |>
    .perform_and_parse(columns = columns)
}

#' @rdname fetch_data
#' @export
fetch_by_url <- function(url, columns = NULL) {
  httr2::request(url) |>
    .perform_and_parse(columns = columns)
}

#' @rdname fetch_data
#' @export
fetch_by_ids <- function(ids) {
  dataset_list <- list()

  i <- 1
  for (id in ids) {
    subset <- httr2::request("https://md.umwelt.info") |>
      httr2::req_url_path_append("dataset", id) |>
      httr2::req_headers(Accept = "application/json") |>
      httr2::req_error(is_error = \(subset) FALSE) |>
      httr2::req_perform() |>
      httr2::resp_body_string()
    page <- jsonlite::stream_in(textConnection(subset), verbose = FALSE)
    dataset_list[[i]] <- page
    i <- i + 1
  }

  dataset_list
}

#' @rdname fetch_data
#' @export
fetch_facet_values <- function(name = "type") {
  if (!name %in% c("type", "topic", "organisation", "license", "language", "resource_type")) {
    stop("Names must be one of: type, topic, organisation, license, language and resource_type.")
  }

  value_list <- httr2::request("https://md.umwelt.info") |>
    httr2::req_url_path_append("facet", name) |>
    httr2::req_perform() |>
    httr2::resp_body_string()

  jsonlite::fromJSON(value_list)
}


#' Internal helper to execute request and parse JSON stream
#' @noRd
.perform_and_parse <- function(req, columns) {
  resp <- req |>
    httr2::req_headers(Accept = "application/json") |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform_connection()

  pages <- list()
  page_number <- 1
  page_size <- 10000

  while (!httr2::resp_stream_is_complete(resp)) {
    lines <- httr2::resp_stream_lines(resp, page_size)

    page <- jsonlite::stream_in(textConnection(lines), pagesize = page_size, verbose = FALSE)

    pages[[page_number]] <- page
    page_number <- page_number + 1
  }
  df <- jsonlite::rbind_pages(pages)

  if (identical(columns, "resource_only")) {
    columns <- c("source", "id", "resources", "title", "quality")
  }
  if (!is.null(columns)) {
    df <- df[, intersect(columns, names(df)), drop = FALSE]
  }

  df
}
