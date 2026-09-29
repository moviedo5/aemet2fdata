# Download the daily history of each station to one CSV per station

For each station, requests AEMET OpenData in natural half-year windows
(1 January - 30 June and 1 July - 31 December; two requests per complete
year) and writes **one CSV with the whole downloaded history of the
station**:


    out_dir/1387.csv
    out_dir/B228.csv

By default, windows are requested from the most recent backwards. Set
`reverse = FALSE` to request them from the oldest forwards. The dates
always follow the usual convention `start_date <= end_date`; the
`reverse` argument changes only the request order.

Once a station has returned data, its download stops after `stop_nodata`
consecutive empty half-years in the search direction. This can save
requests before the beginning of an old record (`reverse = TRUE`) or
after the end of a discontinued record (`reverse = FALSE`). Use
`stop_nodata = Inf` to request the whole specified period.

The CSV uses `";"` as separator and `","` as decimal mark (as
`write.csv2`) and is written in UTF-8 with BOM whatever the locale, so
accents and "ñ" are kept and Excel opens it correctly. Read it with
[`aemet2lfdata`](https://moviedo5.github.io/aemet2fdata/reference/aemet2lfdata.md)
or
[`aemet2fdata`](https://moviedo5.github.io/aemet2fdata/reference/aemet2fdata.md)
(`file = `).

Stations whose file already exists are skipped (`overwrite = FALSE`), so
an interrupted run is resumed by running the same call again. If some
window fails, the file of that station is not written and the station is
reported as `"incomplete"`: run again to retry it.

## Usage

``` r
aemet2csv(
  station_ids,
  start_date,
  end_date,
  api_key,
  out_dir = "aemet_csv",
  vars = NULL,
  reverse = TRUE,
  stop_nodata = 10,
  overwrite = FALSE,
  verbose = TRUE,
  control = list()
)
```

## Arguments

- station_ids:

  Character vector of station identifiers (`station_id` in
  [`aemet2inventory`](https://moviedo5.github.io/aemet2fdata/reference/aemet2inventory.md),
  e.g. `"1387"`; not `wmo_id`).

- start_date, end_date:

  Character or Date (`"YYYY-MM-DD"`), with `start_date <= end_date`.

- api_key:

  Character. AEMET OpenData API key.

- out_dir:

  Directory for the CSV files (created if needed).

- vars:

  `NULL` (all variables) or a character vector of variables to keep.
  Station columns (`fecha`, `station_id`, `station_name`, `provincia`,
  `altitude`) are always kept.

- reverse:

  Logical. If `TRUE` (default), request half-years from `end_date`
  backwards; if `FALSE`, request them from `start_date` forwards.

- stop_nodata:

  Number of consecutive empty half-years, after the first data found,
  that stops the download of a station in the search direction. `Inf`
  requests the whole specified period.

- overwrite:

  Logical. Download again stations whose file exists.

- verbose:

  Logical. Progress messages.

- control:

  List: `max_attempts` (3), `retry_wait` (60 s), `sleep_pause` (1.5 s
  between requests), `clean` (`TRUE`).

## Value

Invisibly, a data.frame with one row per station: `station_id`, `status`
(`"ok"`, `"exists"`, `"nodata"`, `"incomplete"`), `n_requests`,
`n_failed`, `n_rows`, `first`, `last`, `file`.

## See also

[`aemet2lfdata`](https://moviedo5.github.io/aemet2fdata/reference/aemet2lfdata.md),
[`aemet2download`](https://moviedo5.github.io/aemet2fdata/reference/aemet2download.md)

## Examples

``` r
if (FALSE) { # \dontrun{
api_key <- Sys.getenv("AEMET_API_KEY")

# Most recent to oldest (default)
log <- aemet2csv("1387", "1926-01-01", "2025-12-31",
                 api_key = api_key)

# Oldest to most recent
log2 <- aemet2csv("1387", "1926-01-01", "2025-12-31",
                  api_key = api_key, reverse = FALSE)

ld <- aemet2lfdata(file = "aemet_csv/1387.csv",
                   inventory = "inventory.rds")
} # }
```
