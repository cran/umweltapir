#' Download resources from umwelt.info
#'
#' Download all the resources attached to the datasets of a respective query:

#' @param data An unnested and optionally filtered R dataframe which is written as output by one of the functions fetch_by_url, fetch_by_query or fetch_by_id
#' @param data_preprocessed An unnested and optionally filtered R dataframe which is written as output by unnest_and_filter
#' @param description_regex A string to filter only resources with a description containing the string
#' @param formats A list of strings indicating accepted output formats of the recoures
#'   Possible values: see ResourceType in the list of Schemas at the bottom of the API documentation at	https://md.umwelt.info/swagger-ui/ to get a list of existing formats
#' @param base_dir A directory where downloaded resources should be stored.
#'
#' @returns No return value (resources are downloaded into the respective folder)
#'
#' @name download_resources
#' @examples
#' # To download the resources the workflow contains four steps. First you fetch the list of all
#' # datasets belonging to your query.
#' # The input link for the query can be generated in the interface of https://umwelt.info.
#' # See the tutorial
#' # https://umwelt.info/artikel/so-laden-sie-daten-bei-umweltinfo-mit-python-und-r-herunter
#' # for further details.
#' # In a second step the required columns are unnested and you can optionally filter for certain
#' # file formats (in the example here "MicrosoftExcelSpreadsheet" and "Csv") and create a subset of
#' # only those entries where the resource description contains the query (in this example "Ozon").
#' # Note that the unnesting is a prerequisite for preview_resources() and download_resources().
#' # Third, you create a preview of the resulting resources which would be downloaded.
#' # If you want to proceed, you can initiate the download in the fourth and final step.
#' if (interactive()) {
#'   url <-
#'   "https://md.umwelt.info/search/all?query=(Ozon)+AND+organisation%3A%2FLand%2FBayern%2Fopen.bydata"
#'   results <- fetch_by_url(url,
#'     columns = "resource_only"
#'   ) |>
#'     unnest_and_filter(formats =  c("MicrosoftExcelSpreadsheet", "Csv"),
#'     description_regex = "Ozon") |>
#'     preview_resources()
#'   results |> download_resources(base_dir = tempdir())
#' }
NULL

#' @rdname download_resources
#' @importFrom rlang .data
#' @export
unnest_and_filter <- function(data,
                              formats = c("Csv", "Zip", "Json", "JsonLd", "GeoJson", "Tsv", "Pdf", "MicrosoftExcelSpreadsheet"),
                              description_regex = NULL) {
  res <- data |>
    dplyr::mutate(
      resources = purrr::map(
        .data$resources,
        ~ dplyr::mutate(
          .x,
          across(where(is.factor), as.character)
        )
      )
    ) |>
    tidyr::unnest(col = c("resources")) |>
    tidyr::unnest(col = c("quality"))

  res <- res[res$type %in% formats & res$direct_link, ]
  # Arrange so that rows with text in 'description' come first, thus they are kept in case there is a dupliacte without 'description'
  res <- res |>
    dplyr::arrange(url, is.na(.data$description), .data$description == "") |>
    dplyr::distinct(url, .keep_all = TRUE)

  if (!is.null(description_regex)) {
    if ("description" %in% names(res)) {
      matches <- grepl(description_regex, res$description, ignore.case = TRUE)
      # Ensure we don't drop rows if there are NAs in the column
      res <- res[!is.na(matches) & matches, , drop = FALSE]
    } else {
      warning("Warning: description_regex was provided, but column 'description' not found. Filtering skipped.")
    }
  }

  res
}

#' @rdname download_resources
#' @export
preview_resources <- function(data_preprocessed) {
  if (!"description" %in% names(data_preprocessed)) {
    data_preprocessed$description <- NA_character_
  }

  cols_to_keep <- c("id", "title", "type", "description")
  preview <- data_preprocessed[, cols_to_keep, drop = FALSE]
  names(preview)[names(preview) == "description"] <- "resource_description"
  names(preview)[names(preview) == "type"] <- "resource_type"

  print(preview)
  cat("Found", nrow(preview), "resources.\n")
  invisible(data_preprocessed)
}

#' @rdname download_resources
#' @export
download_resources <- function(data_preprocessed, base_dir = tempdir()) {
  if (!dir.exists(base_dir)) dir.create(base_dir, recursive = TRUE)

  for (i in seq_len(nrow(data_preprocessed))) {
    subfolder <- file.path(base_dir, data_preprocessed$source[i])
    if (!dir.exists(subfolder)) dir.create(subfolder, recursive = TRUE)

    destfile <- file.path(subfolder, basename(data_preprocessed$url[i]))

    tryCatch(
      {
        utils::download.file(data_preprocessed$url[i], destfile = destfile, mode = "wb")
        message("Success: ", basename(destfile))
      },
      error = function(e) {
        warning("Error at ", data_preprocessed$url[i], ": ", e$message)
      }
    )
    Sys.sleep(0.2)
  }
}
