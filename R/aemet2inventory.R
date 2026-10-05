#' @encoding UTF-8
#' @title Download AEMET stations inventory (data.frame)
#' @description
#' Fetches the AEMET OpenData inventory of climatological stations, converts
#' ISO-8859-15 text to UTF-8, converts the DMS coordinates to decimal degrees
#' and returns a base-R data.frame with one row per station. Optionally writes
#' it to a file (\code{.csv}, \code{.RData} or \code{.rds}), which can later be
#' passed as \code{inventory} to \code{\link{aemet2lfdata}} without calling
#' the API again.
#'
#' A copy of the inventory (924 stations, downloaded on 2026-09-28) is shipped
#' with the package in \code{inst/extdata/inventory.rds}, so coordinates are
#' available without an API key:
#' \code{system.file("extdata", "inventory.rds", package = "aemet2fdata")}.
#'
#' @param api_key character. AEMET OpenData API key.
#' @param file NULL or character path. If NULL, nothing is written.
#'   If a path is provided, the directory is created if missing.
#'   Supported extensions: \code{.csv}, \code{.RData}, \code{.rds}
#'   (case-insensitive).
#' @param encoding character. Kept for backward compatibility; not used
#'   (AEMET answers are always converted from ISO-8859-15 to UTF-8).
#' @param verbose logical. If TRUE, prints progress messages. Default FALSE.
#' @param max_attempts integer. Max HTTP attempts per request. Default 2 (one retry).
#' @param retry_wait numeric. Seconds to wait between retries. Default 60.
#'
#' @return (invisibly) a data.frame with columns
#' \describe{
#'   \item{station_id}{AEMET station identifier (\code{indicativo}), character}
#'   \item{station_name}{Station name (\code{nombre})}
#'   \item{province}{Province (\code{provincia})}
#'   \item{altitude}{Altitude in metres (\code{altitud}), numeric}
#'   \item{lon}{Longitude in decimal degrees (negative = West)}
#'   \item{lat}{Latitude in decimal degrees (negative = South)}
#'   \item{wmo_id}{WMO synoptic index (\code{indsinop}); \code{NA} if none}
#' }
#' Stations without valid coordinates are dropped.
#'
#' @examples
#' # Inventory shipped with the package (no API key needed)
#' inv0 <- readRDS(system.file("extdata", "inventory.rds", package = "aemet2fdata"))
#' head(inv0)
#'
#' \dontrun{
#' api_key <- Sys.getenv("AEMET_API_KEY")
#'
#' inv <- aemet2inventory(api_key = api_key)
#' head(inv)
#'
#' # Save once and reuse (no further API calls)
#' aemet2inventory(api_key = api_key, file = "inventory.rds")
#' f <- system.file("extdata", "aemet_example.csv", package = "aemet2fdata")
#' ld <- aemet2lfdata(file = f, inventory = "inventory.rds")
#' ld$df
#' }
#' @export
aemet2inventory <- function(api_key,
                            file = NULL,
                            encoding = "UTF-8",
                            verbose = FALSE,
                            max_attempts = 2,
                            retry_wait = 60) {
  
  if (missing(api_key) || is.null(api_key) || !nzchar(api_key)) {
    stop("'api_key' must be provided.")
  }
  
  url <- paste0("https://opendata.aemet.es/opendata/api/valores/",
                "climatologicos/inventarioestaciones/todasestaciones")
  
  if (verbose) message("[AEMET] Requesting inventory envelope...")
  env <- http_get_json(url,
                       query = list(api_key = api_key),
                       max_attempts = max_attempts,
                       retry_wait   = retry_wait,
                       verbose      = verbose)
  
  if (is.null(env$datos) || !nzchar(env$datos)) {
    stop("AEMET response lacks a valid 'datos' URL.")
  }
  
  if (verbose) message("[AEMET] Downloading inventory data...")
  dat <- http_get_json(env$datos,
                       max_attempts = max_attempts,
                       retry_wait   = retry_wait,
                       verbose      = verbose)
  if (is.null(dat)) stop("AEMET inventory could not be downloaded.")
  
  out <- .aemet_inventory_df(dat)
  
  if (verbose) {
    message(sprintf("[AEMET] Retrieved %d stations, kept %d with valid coordinates",
                    NROW(dat), nrow(out)))
  }
  
  write_output_file(out, file, verbose = verbose)
  invisible(out)
}

#' Raw AEMET inventory (parsed JSON) -> standard data.frame
#' @noRd
.aemet_inventory_df <- function(dat) {
  if (!is.data.frame(dat)) dat <- as.data.frame(dat, stringsAsFactors = FALSE)
  
  get_col <- function(nm) {
    x <- dat[[nm]]
    if (is.null(x)) rep(NA_character_, nrow(dat)) else trimws(as.character(x))
  }
  
  out <- data.frame(
    station_id   = get_col("indicativo"),
    station_name = get_col("nombre"),
    province     = get_col("provincia"),
    altitude     = clean_var(get_col("altitud")),
    lon          = dms_to_dd(get_col("longitud")),
    lat          = dms_to_dd(get_col("latitud")),
    wmo_id       = get_col("indsinop"),
    stringsAsFactors = FALSE
  )
  out$wmo_id[!is.na(out$wmo_id) & !nzchar(out$wmo_id)] <- NA_character_
  
  keep <- !is.na(out$station_id) & nzchar(out$station_id) &
    !is.na(out$lon) & !is.na(out$lat)
  out <- out[keep, , drop = FALSE]
  out <- out[order(out$station_id), , drop = FALSE]
  rownames(out) <- NULL
  out
}
