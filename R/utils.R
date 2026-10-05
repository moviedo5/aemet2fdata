#' @importFrom jsonlite fromJSON
#' @importFrom utils modifyList read.table download.file URLencode head
#' @importFrom tools file_ext
#' @importFrom fda.usc fdata ldata
NULL

# =========================================
# utils.R  (shared internal helpers)
# =========================================

# =========================
# COORDINATES
# =========================

#' Convert AEMET DMS coordinates to decimal degrees.
#' Accepts "DDMMSSH" or "DDDMMSSH" (H = N/S/E/W), e.g. "394924N", "025308E".
#' @noRd
dms_to_dd <- function(coord_vec) {
  x <- toupper(trimws(as.character(coord_vec)))
  hemi <- substring(x, nchar(x))
  d <- gsub("[^0-9]", "", x)
  n <- nchar(d)
  ok <- !is.na(x) & n %in% c(6L, 7L) & hemi %in% c("N", "S", "E", "W")
  out <- rep(NA_real_, length(x))
  if (any(ok)) {
    dd  <- d[ok]
    nn  <- n[ok]
    deg <- as.numeric(substr(dd, 1, nn - 4))
    mi  <- as.numeric(substr(dd, nn - 3, nn - 2))
    se  <- as.numeric(substr(dd, nn - 1, nn))
    val <- deg + mi / 60 + se / 3600
    val[hemi[ok] %in% c("S", "W")] <- -val[hemi[ok] %in% c("S", "W")]
    val[mi >= 60 | se >= 60] <- NA_real_
    out[ok] <- val
  }
  out
}

# =========================
# HTTP HELPERS (base R: utils::download.file)
# =========================

#' One GET request. Returns list(ok, status, raw); never throws.
#' The URL (which contains the API key) is never included in messages.
#' @noRd
.http_get_raw <- function(url, query = NULL, timeout_sec = 60) {

  if (length(query) > 0L) {
    q <- paste(
      names(query),
      vapply(query, function(v) URLencode(as.character(v), reserved = TRUE),
             character(1)),
      sep = "=", collapse = "&"
    )
    url <- paste0(url, if (grepl("?", url, fixed = TRUE)) "&" else "?", q)
  }

  tf <- tempfile()
  on.exit(unlink(tf), add = TRUE)
  op <- options(timeout = max(timeout_sec, getOption("timeout")))
  on.exit(options(op), add = TRUE)

  msgs <- character(0)
  res <- tryCatch(
    withCallingHandlers(
      download.file(url, tf, mode = "wb", quiet = TRUE),
      warning = function(w) {
        msgs <<- c(msgs, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) {
      msgs <<- c(msgs, conditionMessage(e))
      -1L
    }
  )

  status <- NA_integer_
  hit <- grep("HTTP status was '[0-9]{3}", msgs, value = TRUE)
  if (length(hit) > 0L) {
    status <- as.integer(sub(".*HTTP status was '([0-9]{3}).*", "\\1", hit[1]))
  }

  if (!identical(as.integer(res), 0L) || !file.exists(tf)) {
    return(list(ok = FALSE, status = status, raw = NULL))
  }

  list(ok = TRUE, status = 200L, raw = readBin(tf, "raw", file.info(tf)$size))
}

#' AEMET answers in ISO-8859-15: raw -> UTF-8 text -> parsed JSON
#' @noRd
.parse_aemet_json <- function(raw) {
  txt <- iconv(rawToChar(raw), from = "ISO-8859-15", to = "UTF-8", sub = "")
  tryCatch(fromJSON(txt, flatten = TRUE), error = function(e) NULL)
}

#' GET + JSON with retries.
#' Returns the parsed JSON, or NULL when AEMET reports "no data" (404).
#' Retries on network errors, HTTP 429/5xx and AEMET "estado" 429.
#' @noRd
http_get_json <- function(url,
                          query = NULL,
                          max_attempts = 3,
                          retry_wait = 60,
                          verbose = FALSE) {

  status <- NA_integer_

  for (attempt in seq_len(max_attempts)) {

    res <- .http_get_raw(url, query = query)
    status <- res$status

    if (res$ok) {
      parsed <- .parse_aemet_json(res$raw)
      estado <- 200L
      if (is.list(parsed) && !is.data.frame(parsed) && !is.null(parsed$estado)) {
        estado <- suppressWarnings(as.integer(parsed$estado[1]))
      }
      if (!is.na(estado) && estado == 404L) return(NULL)
      if (!is.null(parsed) && (is.na(estado) || estado != 429L)) return(parsed)
      status <- if (is.null(parsed)) NA_integer_ else estado
    } else if (!is.na(status) && status == 404L) {
      return(NULL)
    }

    if (attempt < max_attempts) {
      if (verbose) {
        message("[AEMET] Request failed (status ",
                if (is.na(status)) "unknown" else status,
                "), retrying in ", retry_wait, "s (",
                attempt, "/", max_attempts, ")")
      }
      Sys.sleep(retry_wait)
    }
  }

  stop("[AEMET] Request failed after ", max_attempts, " attempts (status ",
       if (is.na(status)) "unknown" else status, ").", call. = FALSE)
}

#' Download the 'datos' URL. Returns raw content or NULL.
#' @noRd
safe_get_raw <- function(url,
                         max_attempts = 5,
                         timeout_sec = 60,
                         verbose = FALSE) {
  for (attempt in seq_len(max_attempts)) {
    res <- .http_get_raw(url, timeout_sec = timeout_sec)
    if (res$ok) return(res$raw)
    if (!is.na(res$status) && res$status == 404L) return(NULL)
    if (attempt < max_attempts) {
      if (verbose) {
        message("[AEMET] Download failed, retrying (", attempt, "/",
                max_attempts, ")")
      }
      Sys.sleep(min(2 * attempt, 10))
    }
  }
  NULL
}

# =========================
# DATA HELPERS
# =========================

#' rbind two data.frames filling missing columns with NA
#' @noRd
rbind_fill <- function(df1, df2) {
  if (is.null(df1)) return(df2)
  if (is.null(df2)) return(df1)

  all_names <- union(names(df1), names(df2))

  for (nm in setdiff(all_names, names(df1))) df1[[nm]] <- NA
  for (nm in setdiff(all_names, names(df2))) df2[[nm]] <- NA

  rbind(df1[all_names], df2[all_names])
}

#' AEMET text values -> numeric ("12,5" -> 12.5, "Ip" -> 0.1, "Varias" -> NA)
#' @noRd
clean_var <- function(x) {
  if (is.numeric(x)) return(as.numeric(x))
  x <- as.character(x)
  x[x %in% c("", "NA")] <- NA
  x[grepl("^Varias$", x)] <- NA
  x <- gsub("Ip", "0.1", x, fixed = TRUE)
  x <- gsub("\\[.*?\\]", "", x)
  x <- gsub(",", ".", x, fixed = TRUE)
  x <- trimws(x)
  suppressWarnings(as.numeric(x))
}

# =========================
# OUTPUT
# =========================

#' Write a data.frame as .csv, .RData or .rds (by extension)
#' @noRd
write_output_file <- function(x, file, verbose = FALSE) {
  if (is.null(file)) return(invisible(NULL))

  dir <- dirname(file)
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  ext <- tolower(file_ext(file))
  if (ext == "csv") {
    if (verbose) message("[AEMET] Writing CSV: ", file)
    .write_csv_utf8(x, file)          # UTF-8 whatever the locale (see utils-csv.R)
  } else if (ext == "rdata") {
    if (verbose) message("[AEMET] Writing RData: ", file)
    save(x, file = file)
  } else if (ext == "rds") {
    if (verbose) message("[AEMET] Writing RDS: ", file)
    saveRDS(x, file = file)
  } else {
    stop("Unsupported file extension. Use .csv, .RData or .rds")
  }

  invisible(NULL)
}

#' Save an R object as .RData or .rds (by extension), under the name 'name'
#' @noRd
.save_aemet_object <- function(x, output_file, name = "x") {
  if (is.null(output_file)) return(invisible(NULL))
  ext_out <- tolower(file_ext(output_file))
  dir_out <- dirname(output_file)
  if (!dir.exists(dir_out)) dir.create(dir_out, recursive = TRUE, showWarnings = FALSE)
  if (ext_out == "rdata") {
    e <- new.env(parent = emptyenv())
    assign(name, x, envir = e)
    save(list = name, envir = e, file = output_file)
  } else if (ext_out == "rds") {
    saveRDS(x, file = output_file)
  } else {
    stop("Unsupported output file extension. Use .RData or .rds")
  }
  invisible(NULL)
}

# =========================
# METADATA
# =========================

#' Internal table describing AEMET daily variables
#' @noRd
aemet_metadata <- data.frame(
  var_name = c(
    "fecha","station_id","station_name","provincia","altitude",
    "tmed","tmin","tmax","prec",
    "velmedia","racha","sol",
    "presMax","presMin",
    "hrMedia","hrMax","hrMin",
    "horatmin","horatmax","horaracha",
    "horaPresMax","horaPresMin",
    "horaHrMax","horaHrMin",
    "dir"
  ),
  var_label_fdata = c(
    NA,NA,NA,NA,NA,
    "temperature_mean","temperature_min","temperature_max","precipitation",
    "wind_speed_mean","wind_gust_max","sunshine_duration",
    "pressure_max","pressure_min",
    "humidity_mean","humidity_max","humidity_min",
    NA,NA,NA,
    NA,NA,
    NA,NA,
    NA
  ),
  var_desc = c(
    NA,NA,NA,NA,NA,
    "Mean daily temperature","Minimum daily temperature","Maximum daily temperature","Daily precipitation",
    "Mean daily wind speed","Maximum daily wind gust","Daily sunshine duration",
    "Maximum daily pressure","Minimum daily pressure",
    "Mean daily relative humidity","Maximum daily relative humidity","Minimum daily relative humidity",
    NA,NA,NA,
    NA,NA,
    NA,NA,
    NA
  ),
  var_units = c(
    "Date","","","","m",
    "\\u00B0C","\\u00B0C","\\u00B0C","mm",
    "km/h","km/h","hours",
    "hPa","hPa",
    "%","%","%",
    "hh:mm","hh:mm","hh:mm",
    "hh","hh",
    "hh:mm","hh:mm",
    "degrees"
  ),
  var_type = c(
    "date","meta","meta","meta","meta",
    "numeric","numeric","numeric","numeric",
    "numeric","numeric","numeric",
    "numeric","numeric",
    "numeric","numeric","numeric",
    "time","time","time",
    "time","time",
    "time","time",
    "categorical"
  ),
  stringsAsFactors = FALSE
)

#' Metadata row of a numeric variable (0 rows if not numeric/unknown)
#' @noRd
.get_aemet_var_meta <- function(var) {
  aemet_metadata[
    aemet_metadata$var_name == var &
      aemet_metadata$var_type == "numeric",
    , drop = FALSE
  ]
}

#' Axis label, e.g. "Mean daily temperature (degrees C)"
#' @noRd
.aemet_ylab <- function(meta_row) {
  units <- gsub("\\\\u00B0", "\u00B0", meta_row$var_units)
  paste0(meta_row$var_desc, " (", units, ")")
}

# =========================
# FUNCTIONAL DATA HELPERS
# (shared by aemet2fdata() and aemet2lfdata())
# =========================

#' Read one input file (.csv, .rds, .RData) as a data.frame
#' @noRd
.read_aemet_file <- function(file) {
  ext <- tolower(file_ext(file))
  if (ext == "csv") {
    # keep station_id as character (e.g. "0076" must not become 76)
    dat <- .read_csv_utf8(file, colClasses = c(station_id = "character"))
  } else if (ext == "rds") {
    dat <- readRDS(file)
  } else if (ext == "rdata") {
    e <- new.env(parent = emptyenv())
    nm <- load(file = file, envir = e)
    if (length(nm) == 0L) stop("No object found in RData file.")
    dat <- e[[nm[1]]]
  } else {
    stop("Unsupported input file extension. Use .csv, .RData or .rds")
  }
  if (!is.data.frame(dat)) stop("The object read from '", file, "' is not a data.frame.")
  dat
}

#' Input data.frame from 'df', or from 'file': one file, several files or a
#' directory (e.g. the output directory of aemet2download())
#' @noRd
.read_aemet_input <- function(df = NULL, file = NULL, station_ids = NULL) {
  if (!is.null(df)) {
    if (!is.data.frame(df)) stop("'df' must be a data.frame.")
    return(df)
  }
  files <- .aemet_input_files(file, station_ids = station_ids)
  lst <- lapply(files, function(f) {
    d <- .read_aemet_file(f)
    if ("fecha" %in% names(d)) d$fecha <- as.Date(d$fecha)
    if ("station_id" %in% names(d)) {
      d$station_id <- as.character(d$station_id)
      # filter while reading (saves memory with many files)
      if (!is.null(station_ids)) d <- d[d$station_id %in% station_ids, , drop = FALSE]
    }
    d
  })
  out <- if (length(lst) == 1L) lst[[1]] else .aemet_bind(lst)
  # Overlapping input files (e.g. two downloads of the same period): keep one
  # record per station and day; otherwise n_days could exceed 365.
  if (all(c("station_id", "fecha") %in% names(out))) {
    # numeric key (station x day): fast and light for millions of records
    key <- match(out$station_id, unique(out$station_id)) * 1e6 +
      as.numeric(as.Date(out$fecha))
    dup <- duplicated(key, fromLast = TRUE)
    if (any(dup)) {
      warning(sum(dup), " duplicated station-day record(s) removed ",
              "(overlapping input files); the last one read is kept.", call. = FALSE)
      out <- out[!dup, , drop = FALSE]
    }
  }
  out
}

#' Curves (one per station-year) and position of every daily record in the
#' curves matrix, computed once with integer arithmetic (no strings), so it is
#' fast and light for millions of records.
#' Returns list(keys, row, col, ok):
#'   keys: data.frame(station_id, year), one row per curve, sorted, with
#'         row names "station_year";
#'   row/col: curve and day (1..365) of each valid record; ok: valid records.
#' Leap years: February 29 -> NA, later days shifted back one (col 60 = Mar 1).
#' @noRd
.aemet_curve_index <- function(dat) {
  lt  <- as.POSIXlt(as.Date(dat$fecha))
  yr  <- lt$year + 1900L
  doy <- lt$yday + 1L
  rm(lt)
  leap <- (yr %% 4L == 0L & yr %% 100L != 0L) | (yr %% 400L == 0L)
  col <- doy - as.integer(leap & doy > 60L)
  col[leap & doy == 60L] <- NA_integer_
  
  stations <- sort(unique(as.character(dat$station_id)))
  code  <- match(dat$station_id, stations) * 10000L + yr
  ucode <- sort(unique(code))
  keys <- data.frame(station_id = stations[ucode %/% 10000L],
                     year = as.integer(ucode %% 10000L),
                     stringsAsFactors = FALSE)
  rownames(keys) <- paste(keys$station_id, keys$year, sep = "_")
  
  row <- match(code, ucode)
  ok  <- !is.na(row) & !is.na(col)
  list(keys = keys, row = row[ok], col = col[ok], ok = ok)
}

#' Matrix (curves x 365) for one variable, rows aligned with idx$keys
#' @noRd
.aemet_curve_matrix <- function(dat, var, idx) {
  mat <- matrix(NA_real_, nrow = nrow(idx$keys), ncol = 365L,
                dimnames = list(rownames(idx$keys), NULL))
  mat[cbind(idx$row, idx$col)] <- clean_var(dat[[var]])[idx$ok]
  mat
}

#' fdata object (curves x 365 days) for one variable
#' @noRd
.aemet_fdata <- function(dat, var, idx) {
  meta_var <- .get_aemet_var_meta(var)
  if (nrow(meta_var) != 1L) {
    stop("Variable '", var, "' is not supported as a functional numeric variable.")
  }
  fd <- fdata(
    .aemet_curve_matrix(dat, var, idx),
    argvals = 1:365,
    rangeval = c(1, 365),
    names = list(
      main = meta_var$var_label_fdata,
      xlab = "days",
      ylab = .aemet_ylab(meta_var)
    )
  )
  rownames(fd$data) <- rownames(idx$keys)
  fd
}

#' Inventory from a data.frame or from a file saved by aemet2inventory()
#' @noRd
.aemet_read_inventory <- function(inventory) {
  if (is.null(inventory) || is.data.frame(inventory)) return(inventory)
  if (is.character(inventory) && length(inventory) == 1L) {
    if (!file.exists(inventory)) stop("Inventory file not found: ", inventory)
    return(.read_aemet_input(file = inventory))
  }
  stop("'inventory' must be a data.frame or a file path (.csv, .rds, .RData).")
}

#' One row per station:
#' station_id, station_name, province, altitude, lon, lat, wmo_id.
#' Values from 'inventory' first; gaps filled from the data itself.
#' @noRd
.aemet_station_meta <- function(dat, stations, inventory = NULL) {
  cols <- c("station_id", "station_name", "province", "altitude",
            "lon", "lat", "wmo_id")
  num_cols <- c("altitude", "lon", "lat")
  meta <- data.frame(station_id = stations, stringsAsFactors = FALSE)
  for (cc in cols[-1]) {
    meta[[cc]] <- if (cc %in% num_cols) NA_real_ else NA_character_
  }
  
  # 1) inventory
  if (!is.null(inventory) && "station_id" %in% names(inventory)) {
    idx <- match(stations, trimws(as.character(inventory$station_id)))
    for (cc in intersect(cols[-1], names(inventory))) {
      v <- inventory[[cc]][idx]
      meta[[cc]] <- if (cc %in% num_cols) clean_var(v) else as.character(v)
    }
  }
  
  # 2) fill gaps from data (aemet2df names: station_name, provincia, altitude)
  src <- c(station_name = "station_name", province = "provincia",
           altitude = "altitude", lon = "lon", lat = "lat", wmo_id = "wmo_id")
  if (!"provincia" %in% names(dat) && "province" %in% names(dat)) {
    src["province"] <- "province"
  }
  first_row <- match(stations, as.character(dat$station_id))
  for (cc in names(src)) {
    if (!src[[cc]] %in% names(dat)) next
    v <- dat[[src[[cc]]]][first_row]
    v <- if (cc %in% num_cols) clean_var(v) else as.character(v)
    miss <- is.na(meta[[cc]])
    meta[[cc]][miss] <- v[miss]
  }
  
  meta[, cols, drop = FALSE]
}
