#' @encoding UTF-8
#' @title Bulk download of AEMET daily data: one file per station and year
#' @description
#' Downloads daily climatological data from AEMET OpenData for long periods
#' and many stations and saves \strong{one file per station and year}:
#' \preformatted{
#' out_dir/1387/1387_1976.rds
#' out_dir/1387/1387_1977.rds
#' ...
#' out_dir/B228/B228_2025.rds
#' }
#' Each file is a data.frame with the daily records of that station-year
#' (\code{fecha}, \code{station_id}, \code{station_name}, \code{provincia},
#' \code{altitude} and the variables).
#'
#' By default the AEMET \emph{all stations} service (\code{todasestaciones})
#' is used, so every station with data is downloaded without giving a list
#' of stations. AEMET only serves short periods per request. By default, the
#' all-stations service uses 15-day windows; when \code{station_ids} is given,
#' individual stations use natural half-years (1 January-30 June and
#' 1 July-31 December). Windows are kept temporarily in \code{out_dir/_tmp}
#' and, when all windows of a year have been downloaded, they are split into
#' the station-year files and deleted.
#'
#' The download is \strong{resumable}: finished years are skipped and, inside
#' an unfinished year, windows already downloaded are not requested again.
#' If the process stops (rate limits, network, closing R), run the same call
#' again. Window files \code{aemet_<start>_<end>.rds} left in \code{out_dir}
#' by version 0.2.0 of this function are reused.
#'
#' Read the result with \code{\link{aemet2lfdata}} or
#' \code{\link{aemet2fdata}} passing \code{out_dir} as \code{file}.
#'
#' @param start_date,end_date Character or Date (\code{"YYYY-MM-DD"}).
#' @param api_key Character. AEMET OpenData API key.
#' @param out_dir Directory where the files are written (created if needed).
#' @param station_ids \code{NULL} (default) to download all stations with the
#'   \code{todasestaciones} service, or a character vector of station
#'   identifiers (column \code{station_id} of \code{\link{aemet2inventory}},
#'   not \code{wmo_id}) to download them one by one.
#' @param vars \code{NULL} (all variables) or a character vector of variables
#'   to keep, e.g. \code{c("tmed", "tmin", "tmax", "prec", "sol")}. Station
#'   columns (\code{fecha}, \code{station_id}, \code{station_name},
#'   \code{provincia}, \code{altitude}) are always kept.
#' @param window_days Length in days of each request to AEMET. If \code{NULL}
#'   (default), the all-stations service uses 15-day windows, while individual
#'   stations use natural half-years (1 January-30 June and
#'   1 July-31 December). A positive integer uses fixed-length windows that
#'   never cross the end of a year. If AEMET reports that the date range is
#'   too long, reduce this value.
#' @param format Format of the station-year files: \code{"rds"} (default) or
#'   \code{"csv"} (separator \code{";"}, decimal \code{","}, UTF-8).
#' @param overwrite Logical. If \code{TRUE}, years already finished are
#'   downloaded again.
#' @param verbose Logical. Progress messages.
#' @param control List of advanced parameters: \code{max_attempts} (3),
#'   \code{retry_wait} (60 s), \code{sleep_pause} (1.5 s between requests),
#'   \code{clean} (\code{TRUE}).
#'
#' @return Invisibly, a data.frame with one row per year (and station, if
#'   \code{station_ids} is given): \code{year}, \code{station_id},
#'   \code{status} (\code{"ok"}, \code{"done"} = finished in a previous run,
#'   \code{"nodata"} or \code{"incomplete"} = some window failed; run again),
#'   \code{n_windows}, \code{n_failed}, \code{n_files} (station-year files
#'   written) and \code{n_rows}.
#'
#' @seealso \code{\link{aemet2csv}} (one CSV per station),
#'   \code{\link{aemet2lfdata}}, \code{\link{aemet2df}},
#'   \code{\link{aemet2inventory}}
#'
#' @examples
#' \dontrun{
#' api_key <- Sys.getenv("AEMET_API_KEY")
#'
#' # 1) Station metadata (coordinates), once
#' aemet2inventory(api_key = api_key, file = "inventory.rds")
#'
#' # 2) All stations, 1976-2025: one file per station and year
#' #    (long: if it stops, run it again)
#' log <- aemet2download(
#'   start_date = "1976-01-01",
#'   end_date   = "2025-12-31",
#'   api_key    = api_key,
#'   out_dir    = "aemet_daily",
#'   vars       = c("tmed", "tmin", "tmax", "prec", "sol")
#' )
#' table(log$status)
#' list.files("aemet_daily/1387")
#'
#' # 3) Functional data: one curve per station-year
#' ld <- aemet2lfdata(file = "aemet_daily", inventory = "inventory.rds")
#'
#' # only some stations (reads only their files)
#' ld2 <- aemet2lfdata(file = "aemet_daily", station_ids = c("1387", "B228"),
#'                     inventory = "inventory.rds")
#'
#' # complete years of stations with the 50 years
#' ld <- subset(ld, ld$df$n_days >= 360)
#' ny <- table(ld$df$station_id)
#' ld50 <- subset(ld, ld$df$station_id %in% names(ny)[ny == 50])
#' }
#' @export
aemet2download <- function(start_date,
                           end_date,
                           api_key,
                           out_dir = "aemet_daily",
                           station_ids = NULL,
                           vars = NULL,
                           window_days = NULL,
                           format = c("rds", "csv"),
                           overwrite = FALSE,
                           verbose = TRUE,
                           control = list()) {

  format <- match.arg(format)
  ctrl <- modifyList(list(max_attempts = 3, retry_wait = 60,
                          sleep_pause = 1.5, clean = TRUE), control)

  if (missing(api_key) || is.null(api_key) || !nzchar(api_key)) {
    stop("'api_key' must be provided.")
  }
  start_date <- as.Date(start_date)
  end_date   <- as.Date(end_date)
  if (is.na(start_date) || is.na(end_date) || end_date < start_date) {
    stop("Invalid 'start_date' / 'end_date'.")
  }
  if (!is.null(window_days)) {
    window_days <- as.integer(window_days)
    if (length(window_days) != 1L || is.na(window_days) || window_days < 1L) {
      stop("'window_days' must be NULL or a positive integer.")
    }
  }

  tmp_dir <- file.path(out_dir, "_tmp")
  dir.create(tmp_dir, recursive = TRUE, showWarnings = FALSE)
  .aemet_adopt_legacy_windows(out_dir, tmp_dir)

  if (is.null(window_days) && !is.null(station_ids)) {
    win <- .aemet_halfyears(start_date, end_date)
  } else {
    wd <- if (is.null(window_days)) 15L else window_days
    win <- .aemet_windows(start_date, end_date, wd)
  }
  win$year <- substr(win$start, 1L, 4L)

  # groups: one per year (all stations) or per station and year
  groups <- if (is.null(station_ids)) {
    data.frame(year = unique(win$year), station_id = NA_character_,
               stringsAsFactors = FALSE)
  } else {
    expand.grid(year = unique(win$year), station_id = as.character(station_ids),
                stringsAsFactors = FALSE)[, c("year", "station_id")]
  }
  groups$status <- NA_character_
  groups$n_windows <- 0L
  groups$n_failed <- 0L
  groups$n_files <- 0L
  groups$n_rows <- 0L

  n_req <- 0L
  for (g in seq_len(nrow(groups))) {
    yr <- groups$year[g]
    st <- groups$station_id[g]
    wy <- win[win$year == yr, , drop = FALSE]
    groups$n_windows[g] <- nrow(wy)

    tag <- paste0(if (!is.na(st)) paste0(st, "_"), wy$start[1], "_", wy$end[nrow(wy)])
    marker <- file.path(tmp_dir, paste0("done_", tag))
    if (file.exists(marker) && !overwrite) {
      groups$status[g] <- "done"
      next
    }

    # ---- windows of this year (cached in _tmp) ----
    cache <- file.path(tmp_dir, paste0("aemet_", if (!is.na(st)) paste0(st, "_"),
                                       wy$start, "_", wy$end, ".rds"))
    failed <- 0L
    for (i in seq_len(nrow(wy))) {
      if (file.exists(cache[i]) && !overwrite) next
      ch <- .aemet_daily_chunk(wy$start[i], wy$end[i],
                               station = if (is.na(st)) NULL else st,
                               api_key = api_key, ctrl = ctrl, verbose = verbose)
      n_req <- n_req + 1L
      if (ch$status == "error" && ch$aemet) {
        stop(ch$msg, "\nWindow ", wy$start[i], " / ", wy$end[i],
             ". If the date range is too long, reduce 'window_days'.",
             call. = FALSE)
      }
      if (ch$status == "ok") {
        saveRDS(.aemet_clean_df(ch$data, vars = vars, clean = ctrl$clean), cache[i])
      } else if (ch$status == "nodata") {
        saveRDS(data.frame(), cache[i])     # mark window as done
      } else {
        failed <- failed + 1L
        if (verbose) {
          message("[AEMET] ", if (!is.na(st)) paste0(st, " "), wy$start[i], "/",
                  wy$end[i], ": ", ch$msg)
        }
      }
      Sys.sleep(ctrl$sleep_pause)
    }
    groups$n_failed[g] <- failed

    if (failed > 0L) {
      groups$status[g] <- "incomplete"
      if (verbose) {
        message("[AEMET] ", if (!is.na(st)) paste0(st, " "), yr, ": ", failed,
                " window(s) failed; year not finished (run again).")
      }
      next
    }

    # ---- year complete: one file per station ----
    d <- .aemet_bind(lapply(cache, readRDS))
    if (!is.na(st) && nrow(d) > 0L) d <- d[d$station_id == st, , drop = FALSE]
    if (!is.null(vars) && nrow(d) > 0L) {
      keep <- intersect(c("fecha", "station_id", "station_name", "provincia",
                          "altitude", vars), names(d))
      d <- d[, keep, drop = FALSE]
    }
    n_files <- .aemet_write_station_years(d, out_dir, format)
    groups$n_files[g] <- n_files
    groups$n_rows[g] <- nrow(d)
    groups$status[g] <- if (nrow(d) == 0L) "nodata" else "ok"
    writeLines(format(Sys.time()), marker)
    unlink(cache)

    if (verbose) {
      message(sprintf("[AEMET] %s%s: %d station file(s), %d rows",
                      if (!is.na(st)) paste0(st, " ") else "", yr,
                      n_files, nrow(d)))
    }
  }

  if (verbose) {
    tb <- table(groups$status)
    message("[AEMET] Done (", n_req, " requests): ",
            paste(names(tb), tb, sep = " = ", collapse = ", "))
  }
  n_inc <- sum(groups$status == "incomplete")
  if (n_inc > 0L) {
    warning(n_inc, " year(s) incomplete. Run the same call again to finish them.",
            call. = FALSE)
  }
  invisible(groups)
}

#' Request windows of 'window_days' days that do not cross the end of a year
#' @noRd
.aemet_windows <- function(start_date, end_date, window_days) {
  years <- as.integer(format(start_date, "%Y")):as.integer(format(end_date, "%Y"))
  out <- lapply(years, function(y) {
    y0 <- max(as.Date(paste0(y, "-01-01")), start_date)
    y1 <- min(as.Date(paste0(y, "-12-31")), end_date)
    ini <- seq(y0, y1, by = window_days)
    fin <- pmin(ini + window_days - 1L, y1)
    data.frame(start = as.character(ini), end = as.character(fin),
               stringsAsFactors = FALSE)
  })
  do.call(rbind, out)
}

#' Write one file per station: out_dir/<station>/<station>_<year>.<ext>
#' Returns the number of files written.
#' @noRd
.aemet_write_station_years <- function(d, out_dir, format = "rds") {
  if (nrow(d) == 0L) return(0L)
  d <- d[order(d$station_id, d$fecha), , drop = FALSE]
  yr <- format(d$fecha, "%Y")
  grp <- split(seq_len(nrow(d)), list(d$station_id, yr), drop = TRUE)
  for (rows in grp) {
    x <- d[rows, , drop = FALSE]
    rownames(x) <- NULL
    st <- x$station_id[1]
    dir_st <- file.path(out_dir, .aemet_safe_name(st))
    if (!dir.exists(dir_st)) dir.create(dir_st, recursive = TRUE, showWarnings = FALSE)
    f <- file.path(dir_st, paste0(.aemet_safe_name(st), "_", yr[rows[1]], ".", format))
    if (format == "rds") saveRDS(x, f) else write_output_file(x, f)
  }
  length(grp)
}

#' Station identifier usable as file/folder name
#' @noRd
.aemet_safe_name <- function(x) gsub("[^A-Za-z0-9_-]", "_", x)

#' Move window files written by aemet2download() 0.2.0 (out_dir/aemet_<ini>_<fin>.rds)
#' to out_dir/_tmp so that they are reused instead of downloaded again
#' @noRd
.aemet_adopt_legacy_windows <- function(out_dir, tmp_dir) {
  old <- list.files(out_dir,
                    pattern = "^aemet_([A-Za-z0-9]+_)?[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{4}-[0-9]{2}-[0-9]{2}\\.rds$")
  if (length(old) > 0L) {
    file.rename(file.path(out_dir, old), file.path(tmp_dir, old))
  }
  invisible(length(old))
}
