# Download AEMET stations inventory (data.frame)

Fetches the AEMET OpenData inventory of climatological stations,
converts ISO-8859-15 text to UTF-8, converts the DMS coordinates to
decimal degrees and returns a base-R data.frame with one row per
station. Optionally writes it to a file (`.csv`, `.RData` or `.rds`),
which can later be passed as `inventory` to
[`aemet2lfdata`](https://moviedo5.github.io/aemet2fdata/reference/aemet2lfdata.md)
without calling the API again.

A copy of the inventory (924 stations, downloaded on 2026-09-28) is
shipped with the package in `inst/extdata/inventory.rds`, so coordinates
are available without an API key:
`system.file("extdata", "inventory.rds", package = "aemet2fdata")`.

## Usage

``` r
aemet2inventory(
  api_key,
  file = NULL,
  encoding = "UTF-8",
  verbose = FALSE,
  max_attempts = 2,
  retry_wait = 60
)
```

## Arguments

- api_key:

  character. AEMET OpenData API key.

- file:

  NULL or character path. If NULL, nothing is written. If a path is
  provided, the directory is created if missing. Supported extensions:
  `.csv`, `.RData`, `.rds` (case-insensitive).

- encoding:

  character. Kept for backward compatibility; not used (AEMET answers
  are always converted from ISO-8859-15 to UTF-8).

- verbose:

  logical. If TRUE, prints progress messages. Default FALSE.

- max_attempts:

  integer. Max HTTP attempts per request. Default 2 (one retry).

- retry_wait:

  numeric. Seconds to wait between retries. Default 60.

## Value

(invisibly) a data.frame with columns

- station_id:

  AEMET station identifier (`indicativo`), character

- station_name:

  Station name (`nombre`)

- province:

  Province (`provincia`)

- altitude:

  Altitude in metres (`altitud`), numeric

- lon:

  Longitude in decimal degrees (negative = West)

- lat:

  Latitude in decimal degrees (negative = South)

- wmo_id:

  WMO synoptic index (`indsinop`); `NA` if none

Stations without valid coordinates are dropped.

## Examples

``` r
# Inventory shipped with the package (no API key needed)
inv0 <- readRDS(system.file("extdata", "inventory.rds", package = "aemet2fdata"))
head(inv0)
#>   station_id          station_name  province altitude       lon      lat wmo_id
#> 1      0002I             VANDELLÒS TARRAGONA       32 0.8713889 40.95806  08169
#> 2      0009X               ALFORJA TARRAGONA      406 0.9633333 41.21389   <NA>
#> 3      0016A       REUS AEROPUERTO TARRAGONA       71 1.1636111 41.14500  08175
#> 4      0016B REUS (CENTRE LECTURA) TARRAGONA      118 1.1088889 41.15417   <NA>
#> 5      0034X                 VALLS TARRAGONA      233 1.2608333 41.29306   <NA>
#> 6      0042Y             TARRAGONA TARRAGONA       55 1.2491667 41.12389   <NA>

if (FALSE) { # \dontrun{
api_key <- Sys.getenv("AEMET_API_KEY")

inv <- aemet2inventory(api_key = api_key)
head(inv)

# Save once and reuse (no further API calls)
aemet2inventory(api_key = api_key, file = "inventory.rds")
f <- system.file("extdata", "aemet_example.csv", package = "aemet2fdata")
ld <- aemet2lfdata(file = f, inventory = "inventory.rds")
ld$df
} # }
```
