#' @encoding UTF-8
#' @title Download the daily history of each station to one CSV per station
#' @description
#' For each station, requests AEMET OpenData in natural half-year windows
#' (1 January - 30 June and 1 July - 31 December; two requests per complete
#' year) and writes \strong{one CSV with the whole downloaded history of the
#' station}:
#' \preformatted{
#' out_dir/1387.csv
#' out_dir/B228.csv
#' }
#'
#' By default, windows are requested from the most recent backwards. Set
#' \code{reverse = FALSE} to request them from the oldest forwards. The dates
#' always follow the usual convention \code{start_date <= end_date}; the
#' \code{reverse} argument changes only the request order.
#'
#' Once a station has returned data, its download stops after
#' \code{stop_nodata} consecutive empty half-years in the search direction.
#' This can save requests before the beginning of an old record
#' (\code{reverse = TRUE}) or after the end of a discontinued record
#' (\code{reverse = FALSE}). Use \code{stop_nodata = Inf} to request the whole
#' specified period.
#'
#' The CSV uses \code{";"} as separator and \code{","} as decimal mark
#' (as \code{write.csv2}) and is written in UTF-8 with BOM whatever the locale,
#' so accents and "ñ" are kept and Excel opens it correctly. Read it with
#' \code{\link{aemet2lfdata}} or \code{\link{aemet2fdata}} (\code{file = }).
#'
#' Stations whose file already exists are skipped (\code{overwrite = FALSE}),
#' so an interrupted run is resumed by running the same call again. If some
#' window fails, the file of that station is not written and the station is
#' reported as \code{"incomplete"}: run again to retry it.
#'
#' @param station_ids Character vector of station identifiers
#'   (\code{station_id} in \code{\link{aemet2inventory}}, e.g. \code{"1387"};
#'   not \code{wmo_id}).
#' @param start_date,end_date Character or Date (\code{"YYYY-MM-DD"}), with
#'   \code{start_date <= end_date}.
#' @param api_key Character. AEMET OpenData API key.
#' @param out_dir Directory for the CSV files (created if needed).
#' @param vars \code{NULL} (all variables) or a character vector of variables
#'   to keep. Station columns (\code{fecha}, \code{station_id},
#'   \code{station_name}, \code{provincia}, \code{altitude}) are always kept.
#' @param reverse Logical. If \code{TRUE} (default), request half-years from
#'   \code{end_date} backwards; if \code{FALSE}, request them from
#'   \code{start_date} forwards.
#' @param stop_nodata Number of consecutive empty half-years, after the first
#'   data found, that stops the download of a station in the search direction.
#'   \code{Inf} requests the whole specified period.
#' @param overwrite Logical. Download again stations whose file exists.
#' @param verbose Logical. Progress messages.
#' @param control List: \code{max_attempts} (3), \code{retry_wait} (60 s),
#'   \code{sleep_pause} (1.5 s between requests), \code{clean} (\code{TRUE}).
#' @return Invisibly, a data.frame with one row per station:
#'   \code{station_id}, \code{status} (\code{"ok"}, \code{"exists"},
#'   \code{"nodata"}, \code{"incomplete"}), \code{n_requests},
#'   \code{n_failed}, \code{n_rows}, \code{first}, \code{last}, \code{file}.
#' @seealso \code{\link{aemet2lfdata}}, \code{\link{aemet2download}}
#' @examples
#' \dontrun{
#' api_key <- Sys.getenv("AEMET_API_KEY")
#'
#' # Most recent to oldest (default)
#' log <- aemet2csv("1387", "1926-01-01", "2025-12-31",
#'                  api_key = api_key)
#'
#' # Oldest to most recent
#' log2 <- aemet2csv("1387", "1926-01-01", "2025-12-31",
#'                   api_key = api_key, reverse = FALSE)
#'
#' ld <- aemet2lfdata(file = "aemet_csv/1387.csv",
#'                    inventory = "inventory.rds")
#' }
#' @export
aemet2csv <- function(station_ids,
                      start_date,
                      end_date,
                      api_key,
                      out_dir = "aemet_csv",
                      vars = NULL,
                      reverse = TRUE,
                      stop_nodata = 10,
                      overwrite = FALSE,
                      verbose = TRUE,
                      control = list()) {

  ctrl <- modifyList(list(max_attempts = 3, retry_wait = 60,
                          sleep_pause = 1.5, clean = TRUE), control)
  if (missing(api_key) || is.null(api_key) || !nzchar(api_key)) {
    stop("'api_key' must be provided.")
  }
  start_date <- as.Date(start_date)
  end_date   <- as.Date(end_date)
  if (is.na(start_date) || is.na(end_date) || end_date < start_date) {
    stop("Invalid 'start_date' / 'end_date': use start_date <= end_date.")
  }
  if (length(reverse) != 1L || is.na(reverse)) stop("'reverse' must be TRUE or FALSE.")
  if (length(stop_nodata) != 1L || is.na(stop_nodata) || stop_nodata < 1) {
    stop("'stop_nodata' must be >= 1 or Inf.")
  }

  station_ids <- unique(as.character(station_ids))
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  win <- .aemet_halfyears(start_date, end_date)
  if (reverse) win <- win[rev(seq_len(nrow(win))), , drop = FALSE]

  log <- data.frame(
    station_id = station_ids,
    status = NA_character_,
    n_requests = 0L,
    n_failed = 0L,
    n_rows = 0L,
    first = as.Date(NA),
    last = as.Date(NA),
    file = file.path(out_dir, paste0(.aemet_safe_name(station_ids), ".csv")),
    stringsAsFactors = FALSE
  )

  for (k in seq_along(station_ids)) {
    st <- station_ids[k]
    if (file.exists(log$file[k]) && !overwrite) {
      log$status[k] <- "exists"
      next
    }
    if (verbose) message("[AEMET] Station ", st, " (", k, "/", length(station_ids), ")")

    pieces <- list()
    failed <- 0L
    empty <- 0L
    found <- FALSE

    for (i in seq_len(nrow(win))) {
      ch <- .aemet_daily_chunk(
        win$start[i], win$end[i], station = st,
        api_key = api_key, ctrl = ctrl, verbose = verbose
      )
      log$n_requests[k] <- log$n_requests[k] + 1L

      if (ch$status == "error" && ch$aemet) stop(ch$msg, call. = FALSE)

      if (ch$status == "ok") {
        pieces[[length(pieces) + 1L]] <- ch$data
        found <- TRUE
        empty <- 0L
      } else if (ch$status == "nodata") {
        if (found) empty <- empty + 1L
      } else {
        failed <- failed + 1L
        if (verbose) {
          message("[AEMET] ", st, " ", win$start[i], "/", win$end[i], ": ", ch$msg)
        }
      }

      Sys.sleep(ctrl$sleep_pause)
      if (found && empty >= stop_nodata) break
    }

    log$n_failed[k] <- failed

    if (failed > 0L) {
      log$status[k] <- "incomplete"
      if (verbose) {
        message("[AEMET] ", st, ": ", failed,
                " window(s) failed; file not written (run again).")
      }
      next
    }
    if (length(pieces) == 0L) {
      log$status[k] <- "nodata"
      next
    }

    d <- .aemet_clean_df(.aemet_bind(pieces), vars = vars, clean = ctrl$clean)
    d <- d[order(d$fecha), , drop = FALSE]
    d <- d[!duplicated(d$fecha), , drop = FALSE]
    rownames(d) <- NULL
    .write_csv_utf8(d, log$file[k])

    log$status[k] <- "ok"
    log$n_rows[k] <- nrow(d)
    log$first[k]  <- min(d$fecha)
    log$last[k]   <- max(d$fecha)

    if (verbose) {
      message(sprintf("[AEMET] %s: %d rows (%s / %s) -> %s",
                      st, nrow(d), log$first[k], log$last[k], log$file[k]))
    }
  }

  if (verbose) {
    tb <- table(log$status)
    message("[AEMET] Done: ", paste(names(tb), tb, sep = " = ", collapse = ", "))
  }
  if (any(log$status == "incomplete")) {
    warning(sum(log$status == "incomplete"),
            " station(s) incomplete. Run the same call again to finish them.",
            call. = FALSE)
  }

  invisible(log)
}
