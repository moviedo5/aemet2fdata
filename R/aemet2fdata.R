#' @encoding UTF-8
#' @title Build an fdata object from AEMET daily data
#' @description
#' Builds an \code{fdata} object (package \pkg{fda.usc}) with one curve per
#' station-year and 365 points per curve.
#'
#' Data can be provided in three ways:
#' \itemize{
#'   \item from an existing data.frame using \code{df}
#'   \item from a file using \code{file} (\code{.csv}, \code{.RData}, \code{.rds})
#'   \item by downloading data from AEMET through \code{\link{aemet2df}}
#' }
#'
#' @details
#' Only numeric meteorological variables are converted into functional data.
#' The output has one row per station-year (row names \code{"station_year"},
#' e.g. \code{"1387_2023"}) and 365 columns, the days of the year
#' (\code{argvals = 1:365}).
#'
#' Leap years: February 29 is removed and the following days are shifted back
#' one position, so column 60 is always March 1. Missing daily values are kept
#' as \code{NA}.
#'
#' Variable labels and units are assigned from internal AEMET metadata, e.g.
#' \itemize{
#'   \item \code{tmed}: main = \code{"temperature_mean"}, ylab = \code{"Mean daily temperature (°C)"}
#'   \item \code{prec}: main = \code{"precipitation"}, ylab = \code{"Daily precipitation (mm)"}
#' }
#'
#' @param station_id Character. AEMET station identifier(s). Required when
#'   downloading from the API; with \code{df} or \code{file} it filters stations.
#' @param var Character. A single variable name, for example \code{"tmed"},
#'   \code{"prec"}, \code{"tmin"} or \code{"tmax"}.
#' @param start_date Character or Date. Initial date in \code{"YYYY-MM-DD"} format.
#' @param end_date Character or Date. Final date in \code{"YYYY-MM-DD"} format.
#' @param last_n_days Integer. Number of last days to download if no dates are
#'   provided. Default: 30.
#' @param api_key Character. AEMET OpenData API key. Used only if data are
#'   downloaded from the API.
#' @param df Optional data.frame with columns \code{fecha} (or \code{date}),
#'   \code{station_id} and \code{var}, as returned by \code{\link{aemet2df}}.
#' @param file NULL, a file (\code{.csv}, \code{.RData}, \code{.rds}), a vector
#'   of files or a directory (e.g. the \code{out_dir} of
#'   \code{\link{aemet2download}}).
#' @param output_file NULL or character path to save the resulting \code{fdata}
#'   object. Supported extensions are \code{.RData} and \code{.rds}.
#' @param verbose Logical. If TRUE, prints progress messages.
#' @param control List of advanced parameters passed to \code{\link{aemet2df}}
#'   when downloading from the API.
#'
#' @return An object of class \code{\link[fda.usc]{fdata}} with one row per
#'   station-year and 365 columns.
#'
#' @seealso \code{\link{aemet2lfdata}}, \code{\link[fda.usc]{fdata}}
#'
#' @examples
#' # Example data shipped with the package (2 stations, 2023-2024)
#' f <- system.file("extdata", "aemet_example.csv", package = "aemet2fdata")
#'
#' fd <- aemet2fdata(file = f, var = "tmed")
#' fd
#' plot(fd)
#' rownames(fd$data)
#'
#' # One station only
#' fd1 <- aemet2fdata(file = f, var = "prec", station_id = "1387")
#' dim(fd1)
#'
#' # fda.usc tools work directly on the result
#' plot(fda.usc::func.mean(fd))
#'
#' \dontrun{
#' # Download from the API
#' api_key <- Sys.getenv("AEMET_API_KEY")
#' fd2 <- aemet2fdata(
#'   station_id = "1387",
#'   var = "tmed",
#'   start_date = "2019-01-01",
#'   end_date = "2021-12-31",
#'   api_key = api_key,
#'   output_file = "aemet_tmed_1387.rds"
#' )
#' }
#' @export
aemet2fdata <- function(station_id = NULL,
                        var,
                        start_date = NULL,
                        end_date = NULL,
                        last_n_days = 30,
                        api_key = NULL,
                        df = NULL,
                        file = NULL,
                        output_file = NULL,
                        verbose = FALSE,
                        control = list()) {
  
  if (missing(var) || length(var) != 1L || !is.character(var) || is.na(var)) {
    stop("'var' must be a single character string.")
  }
  meta_row <- .get_aemet_var_meta(var)
  if (nrow(meta_row) != 1L) {
    stop("Variable '", var, "' is not supported as a functional numeric variable.")
  }
  if (!is.null(df) && !is.null(file)) {
    stop("Use only one input source: either 'df' or 'file'.")
  }
  if (!is.null(station_id)) station_id <- as.character(station_id)
  
  # ---- input source ----
  if (!is.null(df) || !is.null(file)) {
    dat <- .read_aemet_input(df = df, file = file, station_ids = station_id)
  } else {
    if (is.null(station_id)) {
      stop("'station_id' must be provided when downloading from the API.")
    }
    if (is.null(api_key) || !is.character(api_key) || is.na(api_key)) {
      stop("'api_key' must be provided when downloading from the API.")
    }
    dat <- aemet2df(
      station_ids = station_id,
      start_date = start_date,
      end_date = end_date,
      last_n_days = last_n_days,
      vars = var,
      api_key = api_key,
      file = NULL,
      verbose = verbose,
      control = control
    )
  }
  
  if (!is.data.frame(dat) || nrow(dat) == 0L) {
    stop("No data available to build the fdata object.")
  }
  
  # ---- columns ----
  if (!"fecha" %in% names(dat) && "date" %in% names(dat)) dat$fecha <- dat$date
  if (!"fecha" %in% names(dat)) {
    stop("No date column found. Expected 'fecha' or 'date'.")
  }
  if (!var %in% names(dat)) {
    stop("Variable '", var, "' not found in input data.")
  }
  # single-station data may lack 'station_id'
  if (!"station_id" %in% names(dat)) {
    dat$station_id <- if (length(station_id) == 1L) station_id else "station"
  }
  dat$fecha <- as.Date(dat$fecha)
  dat$station_id <- as.character(dat$station_id)
  keep <- !is.na(dat$fecha)
  if (!is.null(station_id)) keep <- keep & dat$station_id %in% station_id
  if (!all(keep)) dat <- dat[keep, , drop = FALSE]
  if (nrow(dat) == 0L) {
    stop("No data available after filtering by station_id.")
  }
  
  # ---- one curve per station-year ----
  fd <- .aemet_fdata(dat, var, .aemet_curve_index(dat))
  
  attr(fd, "var_name")  <- var
  attr(fd, "var_label") <- meta_row$var_label_fdata
  attr(fd, "var_desc")  <- meta_row$var_desc
  attr(fd, "var_units") <- gsub("\\\\u00B0", "\u00B0", meta_row$var_units)
  attr(fd, "source")    <- "AEMET OpenData"
  
  .save_aemet_object(fd, output_file, name = "fd")
  fd
}
