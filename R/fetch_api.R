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
#' @param columns Either a vector of strings containing the selected columns or "resource_only" as a shortcut to select the columns "source", "id", "resources", "title" and "quality".
#'   Possible values: source, id, title, description, types, comment, license, mandatory_registration,
#'   organisations, persons, tags, regions, issued, modified, update_frequency, source_url, source_url_explainer, source_url_type,
#'   machine_readable_source, alternatives, resources, language, bounding_boxes, time_ranges, global_identifier, quality, status, last_harvest, resource_only
#'
#' @returns A tibble containing the dataset entries. Returns an empty
#'   tibble if no results are found.
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
#'   result_list <- fetch_by_query("organisation:/Land/Bayern/open.bydata AND Ozon AND license:/Offen")
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
#' for (i in 1:dim(datasets)[1]) {
#'   print(datasets[i,]$title)
#' }
#'
#' # Example 5: Fetching all possible values for the facet name organisation. This can be e.g. useful
#' # if you want to restrict the results to certain organisations when build your own query,
#' # so you know which organisations are available.
#' name <- "organisation"
#' organisations <- fetch_facet_values(name)
#' head(organisations)
#'
#' # Example 6: Fetch multiple facets at the same time
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
  req <- httr2::request("https://md.umwelt.info/search/all?format=arrow_ipc") |>
    httr2::req_url_query(query = query, language = language)

  req <- .get_column_req(.check_columns(columns), req)

  req$url |>
    arrow::read_ipc_stream()
}

#' @rdname fetch_data
#' @export
fetch_by_url <- function(url, columns = NULL) {
  req <- httr2::request(url) |>
    httr2::req_url_query(format = "arrow_ipc")

  req <- .get_column_req(.check_columns(columns), req)

  req$url |>
    arrow::read_ipc_stream()
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

  dataset_tb <- tibble::as_tibble(dplyr::bind_rows(dataset_list))
  dataset_tb
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

#' Internal helper to get valid columns
#' @noRd
.get_valid_cols <- function() {
  schema <- httr2::request("https://md.umwelt.info/openapi.json") |>
    httr2::req_perform() |>
    httr2::resp_body_string() |>
    jsonlite::fromJSON()
  valid_cols <- schema$components$schemas$Column$enum
  valid_cols
}


#' Internal helper to check column names
#' @noRd
.check_columns <- function(columns) {
  if (length(columns) == 1 && columns == "resource_only") {
    columns <- c("source", "id", "resources", "title", "quality")
  }

  valid_cols <- .get_valid_cols()

  if (!all(columns %in% valid_cols)) { # results in true even if columns = NULL
    invalid <- setdiff(columns, valid_cols)
    stop(
      "Invalid column(s): ", paste(invalid, collapse = ", "), ".\n",
      "Columns must be one or several of: ", paste(valid_cols, collapse = ", "),
      call. = FALSE
    )
  }

  columns
}

#' Internal helper to process column names
#' @noRd
.get_column_req <- function(columns, req) {
  if (!is.null(columns)) {
    # Create a named list where every element is named "columns"
    query_list <- stats::setNames(as.list(columns), rep("columns", length(columns)))

    # Use !!! to splice the list into req_url_query
    req <- req |> httr2::req_url_query(!!!query_list)
  } else {
    req
  }
}
