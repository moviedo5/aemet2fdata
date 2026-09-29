# Bulk download of AEMET daily data: one file per station and year

Downloads daily climatological data from AEMET OpenData for long periods
and many stations and saves **one file per station and year**:


    out_dir/1387/1387_1976.rds
    out_dir/1387/1387_1977.rds
    ...
    out_dir/B228/B228_2025.rds

Each file is a data.frame with the daily records of that station-year
(`fecha`, `station_id`, `station_name`, `provincia`, `altitude` and the
variables).

By default the AEMET *all stations* service (`todasestaciones`) is used,
so every station with data is downloaded without giving a list of
stations. AEMET only serves short periods per request. By default, the
all-stations service uses 15-day windows; when `station_ids` is given,
individual stations use natural half-years (1 January-30 June and 1
July-31 December). Windows are kept temporarily in `out_dir/_tmp` and,
when all windows of a year have been downloaded, they are split into the
station-year files and deleted.

The download is **resumable**: finished years are skipped and, inside an
unfinished year, windows already downloaded are not requested again. If
the process stops (rate limits, network, closing R), run the same call
again. Window files `aemet_<start>_<end>.rds` left in `out_dir` by
version 0.2.0 of this function are reused.

Read the result with
[`aemet2lfdata`](https://moviedo5.github.io/aemet2fdata/reference/aemet2lfdata.md)
or
[`aemet2fdata`](https://moviedo5.github.io/aemet2fdata/reference/aemet2fdata.md)
passing `out_dir` as `file`.

Downloads daily climatological data from AEMET OpenData for long periods
and many stations and saves **one file per station and year**:


    out_dir/1387/1387_1976.rds
    out_dir/1387/1387_1977.rds
    ...
    out_dir/B228/B228_2025.rds

Each file is a data.frame with the daily records of that station-year
(`fecha`, `station_id`, `station_name`, `provincia`, `altitude` and the
variables).

By default the AEMET *all stations* service (`todasestaciones`) is used,
so every station with data is downloaded without giving a list of
stations. AEMET only serves short periods per request. By default, the
all-stations service uses 15-day windows; when `station_ids` is given,
individual stations use natural half-years (1 January-30 June and 1
July-31 December). Windows are kept temporarily in `out_dir/_tmp` and,
when all windows of a year have been downloaded, they are split into the
station-year files and deleted.

The download is **resumable**: finished years are skipped and, inside an
unfinished year, windows already downloaded are not requested again. If
the process stops (rate limits, network, closing R), run the same call
again. Window files `aemet_<start>_<end>.rds` left in `out_dir` by
version 0.2.0 of this function are reused.

Read the result with
[`aemet2lfdata`](https://moviedo5.github.io/aemet2fdata/reference/aemet2lfdata.md)
or
[`aemet2fdata`](https://moviedo5.github.io/aemet2fdata/reference/aemet2fdata.md)
passing `out_dir` as `file`.

## Usage

``` r
aemet2download(
  start_date,
  end_date,
  api_key,
  out_dir = "aemet_daily",
  station_ids = NULL,
  vars = NULL,
  window_days = NULL,
  format = c("rds", "csv"),
  overwrite = FALSE,
  verbose = TRUE,
  control = list()
)

aemet2download(
  start_date,
  end_date,
  api_key,
  out_dir = "aemet_daily",
  station_ids = NULL,
  vars = NULL,
  window_days = NULL,
  format = c("rds", "csv"),
  overwrite = FALSE,
  verbose = TRUE,
  control = list()
)
```

## Arguments

- start_date, end_date:

  Character or Date (`"YYYY-MM-DD"`).

- api_key:

  Character. AEMET OpenData API key.

- out_dir:

  Directory where the files are written (created if needed).

- station_ids:

  `NULL` (default) to download all stations with the `todasestaciones`
  service, or a character vector of station identifiers (column
  `station_id` of
  [`aemet2inventory`](https://moviedo5.github.io/aemet2fdata/reference/aemet2inventory.md),
  not `wmo_id`) to download them one by one.

- vars:

  `NULL` (all variables) or a character vector of variables to keep,
  e.g. `c("tmed", "tmin", "tmax", "prec", "sol")`. Station columns
  (`fecha`, `station_id`, `station_name`, `provincia`, `altitude`) are
  always kept.

- window_days:

  Length in days of each request to AEMET. If `NULL` (default), the
  all-stations service uses 15-day windows, while individual stations
  use natural half-years (1 January-30 June and 1 July-31 December). A
  positive integer uses fixed-length windows that never cross the end of
  a year. If AEMET reports that the date range is too long, reduce this
  value.

- format:

  Format of the station-year files: `"rds"` (default) or `"csv"`
  (separator `";"`, decimal `","`, UTF-8).

- overwrite:

  Logical. If `TRUE`, years already finished are downloaded again.

- verbose:

  Logical. Progress messages.

- control:

  List of advanced parameters: `max_attempts` (3), `retry_wait` (60 s),
  `sleep_pause` (1.5 s between requests), `clean` (`TRUE`).

## Value

Invisibly, a data.frame with one row per year (and station, if
`station_ids` is given): `year`, `station_id`, `status` (`"ok"`,
`"done"` = finished in a previous run, `"nodata"` or `"incomplete"` =
some window failed; run again), `n_windows`, `n_failed`, `n_files`
(station-year files written) and `n_rows`.

Invisibly, a data.frame with one row per year (and station, if
`station_ids` is given): `year`, `station_id`, `status` (`"ok"`,
`"done"` = finished in a previous run, `"nodata"` or `"incomplete"` =
some window failed; run again), `n_windows`, `n_failed`, `n_files`
(station-year files written) and `n_rows`.

## See also

[`aemet2csv`](https://moviedo5.github.io/aemet2fdata/reference/aemet2csv.md)
(one CSV per station),
[`aemet2lfdata`](https://moviedo5.github.io/aemet2fdata/reference/aemet2lfdata.md),
[`aemet2df`](https://moviedo5.github.io/aemet2fdata/reference/aemet2df.md),
[`aemet2inventory`](https://moviedo5.github.io/aemet2fdata/reference/aemet2inventory.md)

## Examples

``` r
if (FALSE) { # \dontrun{
api_key <- Sys.getenv("AEMET_API_KEY")

# 1) Station metadata (coordinates), once
aemet2inventory(api_key = api_key, file = "inventory.rds")

# 2) All stations, 1976-2025: one file per station and year
#    (long: if it stops, run it again)
log <- aemet2download(
  start_date = "1976-01-01",
  end_date   = "2025-12-31",
  api_key    = api_key,
  out_dir    = "aemet_daily",
  vars       = c("tmed", "tmin", "tmax", "prec", "sol")
)
table(log$status)
list.files("aemet_daily/1387")

# 3) Functional data: one curve per station-year
ld <- aemet2lfdata(file = "aemet_daily", inventory = "inventory.rds")

# only some stations (reads only their files)
ld2 <- aemet2lfdata(file = "aemet_daily", station_ids = c("1387", "B228"),
                    inventory = "inventory.rds")

# complete years of stations with the 50 years
ld <- subset(ld, ld$df$n_days >= 360)
ny <- table(ld$df$station_id)
ld50 <- subset(ld, ld$df$station_id %in% names(ny)[ny == 50])
} # }
if (FALSE) { # \dontrun{
api_key <- Sys.getenv("AEMET_API_KEY")

# 1) Station metadata (coordinates), once
aemet2inventory(api_key = api_key, file = "inventory.rds")

# 2) All stations, 1976-2025: one file per station and year
#    (long: if it stops, run it again)
log <- aemet2download(
  start_date = "1976-01-01",
  end_date   = "2025-12-31",
  api_key    = api_key,
  out_dir    = "aemet_daily",
  vars       = c("tmed", "tmin", "tmax", "prec", "sol")
)
table(log$status)
list.files("aemet_daily/1387")

# 3) Functional data: one curve per station-year
ld <- aemet2lfdata(file = "aemet_daily", inventory = "inventory.rds")

# only some stations (reads only their files)
ld2 <- aemet2lfdata(file = "aemet_daily", station_ids = c("1387", "B228"),
                    inventory = "inventory.rds")

# complete years of stations with the 50 years
ld <- subset(ld, ld$df$n_days >= 360)
ny <- table(ld$df$station_id)
ld50 <- subset(ld, ld$df$station_id %in% names(ny)[ny == 50])
} # }
```
