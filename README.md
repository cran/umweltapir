
# umweltapir

<!-- badges: start -->

<!-- badges: end -->

The goal of umweltapir is to provide an R-based access to the datasets
including their resources from the portal <https://umwelt.info>. The
package allows for an easy integration of those datasets into your
R-based workflows. The functionality of the package mirrors the webbased
access as provided at <https://umwelt.info>. You can use the same
queries and get the same datasets by accessing our API.

For more information, the [API endpoint](https://md.umwelt.info/)
provides a [SwaggerUI description of the data
model](https://md.umwelt.info/swagger-ui/#/) where the [search for
multiple
datasets](https://md.umwelt.info/swagger-ui/#/search/text_search) is
explained. See also the [article on our
portal](https://umwelt.info/artikel/r-und-python-pakete) for further
details.

## Installation

The umweltapir package can be installed from CRAN using:

``` r
install.packages("umweltapir")
```

You can also install the development version of umweltapir from
[GitLab](https://about.gitlab.com/) with:

``` r
remotes::install_git(
  url = "https://gitlab.opencode.de/umwelt-info/packages.git",
  ref = "main",
  subdir = "umweltapir"
)
```

## Usage

The package provides a number of functions for querying
<https://umwelt.info> and representing the resulting datasets and their
attached resources in R.

## Example

Example 1: Fetching by a direct URL

``` r
api_url <- "https://md.umwelt.info/search/all?query=Luftqualität"
result_list <- fetch_by_url(api_url)
```

Example 2: Fetching by query string For background how to build a query
see <https://md.umwelt.info/swagger-ui/#/search/text_search>

``` r
result_list <- fetch_by_query("organisation:/Land/Bayern/open.bydata AND Ozon AND license:/Offen")
```

Example 3: Select subset of columns and unnest columns (here the column
“resources” is unnested into its subcolums “type”, “url”, “description”,
“direct_link” and “primary_content”) and in a second step “type” is
further unnested into “path” and “label”

``` r
result_list <- fetch_by_query("(Ozon) AND organisation:/Land/Bayern/open.bydata")
colnames(result_list) # columns before unnesting
result_list <-
  result_list |>
  (\(df) df[, c("source", "id", "resources", "title", "quality"), drop = FALSE])() |>
  tidyr::unnest(col = c("resources")) |>
  tidyr::unnest(col = c("type"))
colnames(result_list) # columns after unnesting
```

Example 4: Fetching by a list of dataset IDs. This can e.g. be useful
for downloading resources. After using preview_resources you can select
a subset of from the preview list using fetch_by_ids() and forward it as
input to download_resources().

``` r
ids <- c(
  "uvk-be/-sen-uvk-umwelt-luft-luftqualitaet-",
  "lanuk-nrw/-publikationen-publikation-bericht-ueber-die-luftqualitaet-im-jahre-2014",
  "metaver-hb/7F0A29F5-ECBC-476D-9C99-DC1A6A8043D0"
)
datasets <- fetch_by_ids(ids)
for (i in 1:dim(datasets)[1]) {
  print(datasets[i,]$title)
}
```

Example 5: Fetching all possible values for the facet name organisation.
This can be e.g. useful if you want to restrict the results to certain
organisations when build your own query, so you know which organisations
are available.

``` r
name <- "organisation"
organisations <- fetch_facet_values(name)
head(organisations)
```

Example 6: Download all the resources attached to the datasets of a
respective query To download the resources the workflow contains four
steps. First you fetch the list of all datasets belonging to your query.
The input link for the query can be generated in the interface of
<https://umwelt.info>. See the
[tutorial](https://umwelt.info/artikel/so-laden-sie-daten-bei-umweltinfo-mit-python-und-r-herunter)
for further details. In a second step the required columns are unnested
and you can optionally filter for certain file formats (in the example
here “MicrosoftExcelSpreadsheet” and “Csv”) and create a subset of only
those entries where the resource description contains the query (in this
example “Ozon”). Note that the unnesting is a prerequisite for
preview_resources() and download_resources(). Third, you create a
preview of the resulting resources which would be downloaded.

``` r
results <- fetch_by_url(
  "https://md.umwelt.info/search/all?query=(Ozon)+AND+organisation%3A%2FLand%2FBayern%2Fopen.bydata",
  columns = "resource_only"
) |>
  unnest_and_filter(formats = c("MicrosoftExcelSpreadsheet", "Csv"), description_regex = "Ozon") |>
  preview_resources()
```

If you want to proceed, you can initiate the download in the fourth and
final step.

``` r
results |> download_resources(base_dir = tempdir())
```

Example 7: Fetch multiple facets at the same time If you want to fetch
more than one facet, the easiest way is to use fetch_by_query() for
this.

``` r
result_list <- fetch_by_query(
  query = "(organisation:/Bund/Destatis OR organisation:'/Land/Statistische Ämter des Bundes und der Länder') AND Abfallentsorgung"
)
```

## Contributing

Contributions are welcome! Whether you want to fix a bug, add a new
feature, or improve the documentation.
