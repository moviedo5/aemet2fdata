# Download AEMET daily data as data.frame

Downloads daily meteorological data from AEMET OpenData API and returns
a base R data.frame.

## Usage

``` r
aemet2df(
  station_ids,
  start_date = NULL,
  end_date = NULL,
  last_n_days = 30,
  vars = NULL,
  api_key,
  file = NULL,
  verbose = FALSE,
  control = list()
)
```

## Arguments

- station_ids:

  Character vector of AEMET station identifiers: column `station_id` of
  [`aemet2inventory`](https://moviedo5.github.io/aemet2fdata/reference/aemet2inventory.md)
  (AEMET *indicativo*, e.g. `"1387"`), not `wmo_id`.

- start_date:

  Character or Date. Initial date ("YYYY-MM-DD").

- end_date:

  Character or Date. Final date ("YYYY-MM-DD").

- last_n_days:

  Integer. Number of last days if no dates are provided.

- vars:

  NULL or character vector of variables to keep.

- api_key:

  Character. AEMET OpenData API key.

- file:

  Optional output file (.csv, .RData, .rds).

- verbose:

  Logical.

- control:

  List of advanced parameters:

  - `max_attempts` (default 3)

  - `retry_wait` (default 60)

  - `sleep_pause` (default 1.5)

  - `clean` (default TRUE): convert numeric variables (e.g. `"12,5"`,
    `"Ip"`) to numeric

## Value

A data.frame with daily meteorological observations.

## Details

Data are retrieved in natural half-year windows (1 January-30 June and 1
July-31 December) with retry logic to ensure robustness. Requests use
base R
([`utils::download.file`](https://rdrr.io/r/utils/download.file.html));
the API key is never printed in error messages.

If `start_date` and `end_date` are not provided, the last `last_n_days`
are downloaded (default: 30 days).

The resulting data.frame typically includes:

- fecha:

  Date of observation (Date)

- station_id:

  Station identifier

- station_name:

  Station name

- provincia:

  Province

- altitude:

  Altitude (meters)

- tmed:

  Mean temperature (°C)

- tmin:

  Minimum temperature (°C)

- tmax:

  Maximum temperature (°C)

- prec:

  Precipitation (mm)

- velmedia:

  Mean wind speed (km/h)

- racha:

  Maximum wind gust (km/h)

- sol:

  Sunshine duration (hours)

Units follow AEMET OpenData conventions.

## Examples

``` r
if (FALSE) { # \dontrun{
api_key <- "YOUR_API_KEY"

df <- aemet2df(
  station_ids = "1387",
  start_date = "2020-01-01",
  end_date = "2020-01-31",
  vars = "tmed",
  api_key = api_key
)

# Basic time series plot (base R)
plot(df$fecha, df$tmed,
     type = "l",
     xlab = "Date",
     ylab = "Mean temperature (°C)",
     main = "Daily mean temperature")
} # }
```
