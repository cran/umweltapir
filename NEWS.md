# umweltapir 0.2.0

## Breaking changes

* This version is not fully compatible with the prior version due to differences in the JSON schema and Arrow IPC serialization.

## New features

* Use Arrow IPC serialization format for building data-frame-like output to increase performance: The umwelt.info streaming endpoints `/search/all` and `/dataset/all` now support Arrow IPC in addition to ND-JSON. Using Arrow IPC, the output is returned as a tibble.

* Use column-selection API to reduce network traffic: The umwelt.info streaming endpoints `/search/all` and `/dataset/all` now support reducing the amount of transmitted data by choosing which columns to serialize.

# umweltapir 0.1.0

* Initial CRAN submission.
