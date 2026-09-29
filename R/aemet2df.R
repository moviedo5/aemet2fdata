#' @encoding UTF-8
#'
#' @title Download AEMET daily data as data.frame
#'
#' @description
#' Downloads daily meteorological data from AEMET OpenData API and returns
#' a base R data.frame.
#'
#' @details
#' Data are retrieved in natural half-year windows (1 January-30 June and
#' 1 July-31 December) with retry logic to ensure robustness.
#' Requests use base R (\code{utils::download.file}); the API key is never
#' printed in error messages.
#'
#' If \code{start_date} and \code{end_date} are not provided, the last
#' \code{last_n_days} are downloaded (default: 30 days).
#'
#' The resulting data.frame typically includes:
#' \describe{
#'   \item{fecha}{Date of observation (Date)}
#'   \item{station_id}{Station identifier}
#'   \item{station_name}{Station name}
#'   \item{provincia}{Province}
#'   \item{altitude}{Altitude (meters)}
#'   \item{tmed}{Mean temperature (°C)}
#'   \item{tmin}{Minimum temperature (°C)}
#'   \item{tmax}{Maximum temperature (°C)}
#'   \item{prec}{Precipitation (mm)}
#'   \item{velmedia}{Mean wind speed (km/h)}
#'   \item{racha}{Maximum wind gust (km/h)}
#'   \item{sol}{Sunshine duration (hours)}
#' }
#'
#' Units follow AEMET OpenData conventions.
#'
#' @param station_ids Character vector of AEMET station identifiers: column
#'   \code{station_id} of \code{\link{aemet2inventory}} (AEMET
#'   \emph{indicativo}, e.g. \code{"1387"}), not \code{wmo_id}.
#' @param start_date Character or Date. Initial date ("YYYY-MM-DD").
#' @param end_date Character or Date. Final date ("YYYY-MM-DD").
#' @param last_n_days Integer. Number of last days if no dates are provided.
#' @param vars NULL or character vector of variables to keep.
#' @param api_key Character. AEMET OpenData API key.
#' @param file Optional output file (.csv, .RData, .rds).
#' @param verbose Logical.
#' @param control List of advanced parameters:
#'   \itemize{
#'     \item \code{max_attempts} (default 3)
#'     \item \code{retry_wait} (default 60)
#'     \item \code{sleep_pause} (default 1.5)
#'     \item \code{clean} (default TRUE): convert numeric variables
#'       (e.g. \code{"12,5"}, \code{"Ip"}) to numeric
#'   }
#'
#' @return A data.frame with daily meteorological observations.
#'
#' @examples
#' \dontrun{
#' api_key <- "YOUR_API_KEY"
#'
#' df <- aemet2df(
#'   station_ids = "1387",
#'   start_date = "2020-01-01",
#'   end_date = "2020-01-31",
#'   vars = "tmed",
#'   api_key = api_key
#' )
#'
#' # Basic time series plot (base R)
#' plot(df$fecha, df$tmed,
#'      type = "l",
#'      xlab = "Date",
#'      ylab = "Mean temperature (°C)",
#'      main = "Daily mean temperature")
#' }
#'
#' @export
aemet2df <- function(station_ids,
                     start_date = NULL,
                     end_date = NULL,
                     last_n_days = 30,
                     vars = NULL,
                     api_key,
                     file = NULL,
                     verbose = FALSE,
                     control = list()) {
  
  defaults <- list(
    max_attempts = 3,
    retry_wait = 60,
    sleep_pause = 1.5,
    clean = TRUE
  )
  ctrl <- modifyList(defaults, control)
  
  if (missing(api_key) || is.null(api_key) || !nzchar(api_key)) {
    stop("'api_key' must be provided.")
  }
  
  if (is.null(start_date) || is.null(end_date)) {
    end_date   <- Sys.Date()
    start_date <- end_date - last_n_days
  }
  
  start_date <- as.Date(start_date)
  end_date   <- as.Date(end_date)
  
  if (is.na(start_date) || is.na(end_date) || end_date < start_date) {
    stop("Invalid 'start_date' / 'end_date': use start_date <= end_date.")
  }

  windows <- .aemet_halfyears(start_date, end_date)
  windows <- windows[rev(seq_len(nrow(windows))), , drop = FALSE]
  station_ids <- as.character(station_ids)
  
  data_list <- list()
  failed <- character(0)
  
  for (st in station_ids) {
    for (i in seq_len(nrow(windows))) {
      ini <- windows$start[i]
      fin <- windows$end[i]
      ch <- .aemet_daily_chunk(ini, fin, station = st, api_key = api_key,
                               ctrl = ctrl, verbose = verbose)
      if (ch$status == "ok") {
        data_list[[length(data_list) + 1L]] <- ch$data
      } else if (ch$status == "error") {
        if (ch$aemet) stop(ch$msg, call. = FALSE)
        failed <- c(failed, paste0(st, " ", ini, "/", fin, ": ", ch$msg))
      }
      Sys.sleep(ctrl$sleep_pause)
    }
  }
  
  if (length(failed) > 0L) {
    warning(length(failed), " request(s) failed and were skipped:\n",
            paste(utils::head(failed, 10), collapse = "\n"), call. = FALSE)
  }
  
  if (length(data_list) == 0L) {
    warning("No data retrieved for station(s) ",
            paste(station_ids, collapse = ", "),
            ". Use the AEMET station identifier ('station_id' in ",
            "aemet2inventory(), e.g. \"1387\"), not 'wmo_id'.", call. = FALSE)
    return(data.frame())
  }
  
  out <- .aemet_clean_df(.aemet_bind(data_list), vars = vars, clean = ctrl$clean)
  out <- out[order(out$station_id, out$fecha), , drop = FALSE]
  rownames(out) <- NULL
  
  write_output_file(out, file, verbose = verbose)
  
  return(out)
}
