# =========================================
# utils-daily.R  (internal helpers for AEMET daily data requests)
# =========================================

#' URL of the daily climatological values for one station or all stations
#' @noRd
.aemet_daily_url <- function(ini, fin, station = NULL) {
  paste0(
    "https://opendata.aemet.es/opendata/api/valores/climatologicos/diarios/datos/",
    "fechaini/", ini, "T00:00:00UTC/",
    "fechafin/", fin, "T23:59:59UTC/",
    if (is.null(station)) "todasestaciones" else paste0("estacion/", station)
  )
}

#' Download one date window (one station, or all stations if station = NULL).
#' Returns list(status = "ok" | "nodata" | "error", data, msg, aemet); never
#' throws. aemet = TRUE: AEMET answered with an error description (invalid
#' key, date range too long, ...), which retrying will not fix.
#' @noRd
.aemet_daily_chunk <- function(ini, fin, station = NULL, api_key, ctrl,
                               verbose = FALSE) {
  res <- function(status, data = NULL, msg = "", aemet = FALSE) {
    list(status = status, data = data, msg = msg, aemet = aemet)
  }
  env <- tryCatch(
    http_get_json(.aemet_daily_url(ini, fin, station),
                  query = list(api_key = api_key),
                  max_attempts = ctrl$max_attempts,
                  retry_wait = ctrl$retry_wait,
                  verbose = verbose),
    error = function(e) e
  )
  if (inherits(env, "error")) return(res("error", msg = conditionMessage(env)))
  if (is.null(env)) return(res("nodata", msg = "no data"))
  if (is.null(env$datos) || !nzchar(env$datos)) {
    desc <- if (!is.null(env$descripcion)) env$descripcion else "no 'datos' URL"
    return(res("error", msg = paste0("AEMET: ", desc, " (estado ", env$estado, ")"),
               aemet = TRUE))
  }
  raw <- safe_get_raw(env$datos, verbose = verbose)
  if (is.null(raw)) return(res("error", msg = "download of 'datos' failed"))
  dat <- .parse_aemet_json(raw)
  if (!is.data.frame(dat)) return(res("error", msg = "invalid JSON in 'datos'"))
  if (nrow(dat) == 0L) return(res("nodata", msg = "no data"))
  res("ok", data = dat)
}

#' Raw AEMET daily data -> standard data.frame
#' (fecha, station_id, station_name, provincia, altitude, variables)
#' @noRd
.aemet_clean_df <- function(out, vars = NULL, clean = TRUE) {
  if (!is.null(vars)) {
    keep <- intersect(c("fecha", "indicativo", "nombre", "provincia", "altitud",
                        vars), names(out))
    out <- out[, keep, drop = FALSE]
  }
  if (clean) {
    num_cols <- aemet_metadata$var_name[aemet_metadata$var_type == "numeric"]
    for (col in intersect(c(num_cols, "altitud"), names(out))) {
      out[[col]] <- clean_var(out[[col]])
    }
  }
  names(out)[names(out) == "indicativo"] <- "station_id"
  names(out)[names(out) == "nombre"]     <- "station_name"
  names(out)[names(out) == "altitud"]    <- "altitude"
  if ("fecha" %in% names(out)) out$fecha <- as.Date(out$fecha)
  if ("station_id" %in% names(out)) out$station_id <- as.character(out$station_id)
  rownames(out) <- NULL
  out
}

#' Fast row-binding of a list of data.frames: columns matched by name and
#' missing columns filled with NA of the right type (Date, numeric, character)
#' @noRd
.aemet_bind <- function(lst) {
  lst <- Filter(function(d) is.data.frame(d) && nrow(d) > 0L, lst)
  if (length(lst) == 0L) return(data.frame())
  if (length(lst) == 1L) return(lst[[1]])
  nms <- unique(unlist(lapply(lst, names), use.names = FALSE))
  cols <- lapply(nms, function(nm) {
    tmpl <- NULL
    for (d in lst) if (nm %in% names(d)) { tmpl <- d[[nm]]; break }
    pieces <- lapply(lst, function(d) {
      if (nm %in% names(d)) d[[nm]] else tmpl[rep(NA_integer_, nrow(d))]
    })
    do.call(c, unname(pieces))
  })
  names(cols) <- nms
  out <- as.data.frame(cols, stringsAsFactors = FALSE, optional = TRUE)
  rownames(out) <- NULL
  out
}

#' Files to read: 'file' may be a file, a vector of files or a directory
#' (all .csv/.rds/.RData files inside, recursively, except the temporary
#' folder '_tmp' of aemet2download()). With 'station_ids', station-year files
#' named '<station>_<year>.<ext>' of other stations are not read.
#' @noRd
.aemet_input_files <- function(file, station_ids = NULL) {
  file <- as.character(file)
  is_dir <- dir.exists(file)
  in_dirs <- unlist(lapply(file[is_dir], function(d) {
    f <- list.files(d, pattern = "\\.(csv|rds|rdata)$", ignore.case = TRUE,
                    recursive = TRUE, full.names = TRUE)
    f[!grepl("(^|/)_tmp/", substring(f, nchar(d) + 1L))]
  }), use.names = FALSE)
  files <- c(file[!is_dir], in_dirs)
  if (!is.null(station_ids) && length(in_dirs) > 0L) {
    b  <- basename(files)
    sy <- grepl("^.+_[0-9]{4}\\.(csv|rds|rdata)$", b, ignore.case = TRUE)
    st <- sub("_[0-9]{4}\\.[A-Za-z]+$", "", b)
    files <- files[!sy | st %in% .aemet_safe_name(station_ids) | !(files %in% in_dirs)]
  }
  if (length(files) == 0L) stop("No .csv, .rds or .RData files found in 'file'.")
  miss <- files[!file.exists(files)]
  if (length(miss) > 0L) stop("File(s) not found: ", paste(miss, collapse = ", "))
  sort(files)
}

#' Natural half-year windows (1 Jan - 30 Jun, 1 Jul - 31 Dec), clipped to period
#' @noRd
.aemet_halfyears <- function(start_date, end_date) {
  start_date <- as.Date(start_date)
  end_date <- as.Date(end_date)
  yrs <- as.integer(format(start_date, "%Y")):as.integer(format(end_date, "%Y"))
  ini <- as.Date(paste0(rep(yrs, each = 2L), c("-01-01", "-07-01")))
  fin <- as.Date(paste0(rep(yrs, each = 2L), c("-06-30", "-12-31")))
  ok <- fin >= start_date & ini <= end_date
  data.frame(
    start = as.character(pmax(ini[ok], start_date)),
    end = as.character(pmin(fin[ok], end_date)),
    stringsAsFactors = FALSE
  )
}
