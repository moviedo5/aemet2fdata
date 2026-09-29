# aemet2fdata 0.2.0

## Bug fixes

* `aemet2lfdata()` now builds one curve per **station-year**. Previously,
  curves from different stations in the same year could be mixed, and
  `ldata$df` had one row per station instead of one row per curve. Now
  `nrow(ldata$df) == nrow(ldata[[v]])` for every functional variable, and
  row names (`"station_year"`, e.g. `"1387_2023"`) are shared by `df` and
  all `fdata` elements.

* Leap years are now handled correctly: February 29 is removed and days
  after February are shifted accordingly, so column 60 always represents
  March 1.

* `aemet2fdata()` now correctly uses the supplied data and returns one
  curve per station-year, consistently with `aemet2lfdata()`.

* `aemet2inventory()` now returns only station metadata available from the
  AEMET inventory: `station_id`, `station_name`, `province`, `altitude`,
  `lon`, `lat` and `wmo_id` (the AEMET synoptic index `indsinop`).
  Conversion of DMS coordinates to decimal degrees accepts both `DDMMSS`
  and `DDDMMSS` formats.

* Station metadata in `ldata$df` (`province`, `altitude`, `lon`, `lat` and
  `wmo_id`) are obtained from the inventory and completed, when possible,
  from the daily data.

* `aemet2df()` now converts all numeric AEMET variables to numeric,
  including humidity, pressure and altitude variables. Previously only a
  subset of the meteorological variables was converted.

* Station identifiers are always kept as character strings, so identifiers
  with leading zeros (e.g. `"0076"`) are preserved when reading CSV files.

## New features and changes

* New `aemet2csv()` for downloading long daily histories and storing
  **one CSV file per station** (`out_dir/<station_id>.csv`).

  Downloads are made in natural half-year periods:

  - 1 January to 30 June
  - 1 July to 31 December

  The first and last periods are truncated when `start_date` or `end_date`
  fall inside a half-year.

  With `reverse = TRUE` (the default), periods are requested from the most
  recent backwards. With `reverse = FALSE`, they are requested from the
  oldest forwards. `start_date` must always be earlier than or equal to
  `end_date`.

  When downloading backwards, a station stops after `stop_nodata`
  consecutive empty half-years once data have been found
  (`stop_nodata = 4` by default, corresponding to two years). Existing
  station files are skipped. If a request fails, the station is reported
  as `"incomplete"` and its final CSV is not written, so the download can
  be retried safely.

* `aemet2df()` uses the same natural half-year periods for daily
  individual-station requests.

* New `aemet2download()` provides resumable bulk downloads for long
  periods, saving **one file per station and year**:

  `out_dir/<station_id>/<station_id>_<year>.rds`

  or the equivalent `.csv` file.

  By default, it uses the AEMET `todasestaciones` service in short
  `window_days` periods (15 days by default), temporarily stores those
  downloads in `out_dir/_tmp`, and splits them into station-year files.
  Completed station-years are skipped and failed windows can be retried by
  running the same call again.

  When `station_ids` is supplied, individual-station downloads use the
  natural half-year periods described above.

* `file` in `aemet2fdata()` and `aemet2lfdata()` can be a single file, a
  vector of files or a directory. Directories are read recursively, which
  allows the output of `aemet2download()` to be used directly. When
  `station_id` or `station_ids` are supplied, only the requested stations
  are retained.

* `ldata$df` now includes `n_days`, the number of observed calendar days
  for each station-year. This can be used to remove incomplete curves, for
  example with `subset(ld, ld$df$n_days >= 360)`.

* `aemet2lfdata()` now builds objects with the `fda.usc::ldata()`
  constructor. Standard `fda.usc` methods such as `plot()`, `subset()` and
  `[` therefore work directly on the returned object.

* `inventory` in `aemet2lfdata()` can be either an inventory `data.frame`
  or the path to a file previously saved with `aemet2inventory(file = ...)`.
  This allows the inventory to be downloaded once and reused.

* `aemet2lfdata()` warns when requested variables are not available in the
  data and reports when station coordinates are unavailable.

* CSV files are written in UTF-8 with BOM, using `;` as field separator
  and `,` as decimal separator, independently of the current locale.
  CSV input is read consistently so accented characters and station names
  are preserved. This applies to `aemet2df()`, `aemet2download()`,
  `aemet2csv()`, `aemet2fdata()` and `aemet2lfdata()`.

* HTTP requests now use base R (`utils::download.file()`), removing the
  dependency on `httr`. The API key is not included in error messages.
  AEMET "no data" responses (404) are not retried, while rate-limit
  responses (429) are retried.

* Failed requests are retried once by default
  (`max_attempts = 2`, `retry_wait = 60`). More attempts can be requested
  with `control = list(max_attempts = 3)`.

* Error messages now clarify that station identifiers correspond to the
  AEMET `station_id` (`indicativo`, e.g. `"1387"`), not to `wmo_id`.

* New example data file `inst/extdata/aemet_example.csv`, containing
  stations 1387 and B228 for 2023-2024, allows examples and the vignette to
  run without an API key.

* Internal helper functions are no longer exported to the help index.

* `LazyData` has been removed from `DESCRIPTION`, since the package does not
  contain a `data/` directory.

* `inst/CITATION` has been updated.

# aemet2fdata 0.1.1

* `aemet2lfdata()` returns an `ldata` object compatible with `fda.usc`.

* Functional-variable labels and units are taken from the internal AEMET
  metadata.

# aemet2fdata 0.1.0

* First version of the package, including `aemet2inventory()`,
  `aemet2df()`, `aemet2fdata()` and `aemet2lfdata()`.
