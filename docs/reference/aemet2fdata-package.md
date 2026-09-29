# aemet2fdata: Functional Data from AEMET OpenData

Tools to download daily meteorological data from the AEMET OpenData API
and convert them into functional data objects (`fdata` and `ldata`) for
analysis with the fda.usc package.

## Details

Main functions:

- [`aemet2inventory`](https://moviedo5.github.io/aemet2fdata/reference/aemet2inventory.md):
  station metadata (id, name, province, altitude, longitude, latitude).

- [`aemet2df`](https://moviedo5.github.io/aemet2fdata/reference/aemet2df.md):
  daily data as a base-R data.frame.

- [`aemet2csv`](https://moviedo5.github.io/aemet2fdata/reference/aemet2csv.md):
  whole daily history of each station, requested in half-year windows,
  saved as one CSV (UTF-8) per station.

- [`aemet2download`](https://moviedo5.github.io/aemet2fdata/reference/aemet2download.md):
  resumable bulk download (all stations, long periods) to one file per
  station and year.

- [`aemet2fdata`](https://moviedo5.github.io/aemet2fdata/reference/aemet2fdata.md):
  one variable as an `fdata` object (one curve per station-year, 365
  days).

- [`aemet2lfdata`](https://moviedo5.github.io/aemet2fdata/reference/aemet2lfdata.md):
  several variables as an `ldata` object (a `df` with one row per curve
  plus one `fdata` per variable).

An example data file is available at
`system.file("extdata", "aemet_example.csv", package = "aemet2fdata")`
(daily data of stations 1387, A Coruña, and B228, Palma Puerto,
2023-2024; source: AEMET OpenData).

A personal API key is required to download data:
<https://opendata.aemet.es/centrodedescargas/altaUsuario>.

Other R packages also access AEMET OpenData, with different goals:
climaemet (many AEMET services, tidy and spatial output, climate
graphics) and meteospain (several Spanish meteorological services with a
common format). aemet2fdata focuses on long daily series stored locally
and on their conversion to functional data.

Data source: © AEMET (Agencia Estatal de Meteorología).

## References

Febrero-Bande, M. and Oviedo de la Fuente, M. (2012). Statistical
Computing in Functional Data Analysis: The R Package fda.usc. *Journal
of Statistical Software*, 51(4), 1-28.
[doi:10.18637/jss.v051.i04](https://doi.org/10.18637/jss.v051.i04)

## See also

Useful links:

- <https://moviedo5.github.io/aemet2fdata/>

- <https://github.com/moviedo5/aemet2fdata>

- Report bugs at <https://github.com/moviedo5/aemet2fdata/issues>

## Author

**Maintainer**: Manuel Oviedo de la Fuente <manuel.oviedo@udc.es>
([ORCID](https://orcid.org/0000-0001-7360-3249))

Authors:

- Manuel Oviedo de la Fuente <manuel.oviedo@udc.es>
  ([ORCID](https://orcid.org/0000-0001-7360-3249))
