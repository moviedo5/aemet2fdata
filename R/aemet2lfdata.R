#' @encoding UTF-8
#' @title Build an ldata object from AEMET daily data
#' @description
#' Builds an \code{ldata} object (package \pkg{fda.usc}), a list whose first
#' element \code{df} is a data.frame with one row per curve and whose remaining
#' elements are \code{fdata} objects, one per variable. The structure is that
#' of \code{\link[fda.usc]{ldata}}, so it can be used directly with
#' \pkg{fda.usc} tools (\code{plot}, \code{subset}, \code{[}, \code{fregre.lm},
#' \code{classif.gsam}, ...).
#'
#' @details
#' Data can be provided:
#' \itemize{
#'   \item from an existing data.frame (\code{df})
#'   \item from file (\code{file})
#'   \item downloaded from AEMET via \code{\link{aemet2df}}
#' }
#'
#' Each functional object has:
#' \itemize{
#'   \item one curve per station-year
#'   \item 365 points per curve (February 29 removed; in leap years the days
#'     after February 28 are shifted back one position, so column 60 is always
#'     March 1)
#'   \item \code{argvals = 1:365} ("days")
#' }
#'
#' The first element, \code{ldata$df}, contains one row per curve, that is,
#' one row per station-year combination: the station metadata
#' (\code{station_id}, \code{station_name}, \code{province}, \code{altitude}
#' in metres, \code{lon} and \code{lat} in decimal degrees and \code{wmo_id})
#' is repeated for every year of that station, and
#' \code{year} identifies the curve; \code{n_days} is the number of days of
#' that station-year present in the data (useful to discard incomplete years,
#' e.g. \code{subset(ld, ld$df$n_days >= 360)}). Row names are \code{"station_year"} and
#' coincide with the row names of every \code{fdata} element, so
#' \code{nrow(ldata$df) == nrow(ldata[[v]])} for all variables.
#'
#' Station metadata is taken from \code{inventory} (downloaded with
#' \code{\link{aemet2inventory}} if \code{api_key} is given and
#' \code{inventory} is \code{NULL}); missing values are filled from the data
#' itself. The daily AEMET data do not include coordinates, so without an
#' inventory \code{lon} and \code{lat} are \code{NA}.
#'
#' @param station_ids Character vector of AEMET station identifiers (column
#'   \code{station_id} of \code{\link{aemet2inventory}}, not \code{wmo_id}).
#'   Required if downloading; otherwise used as a filter.
#' @param vars Character vector of variables. By default, all numeric
#'   variables present in the data. Requested variables that are not in the
#'   data are dropped with a warning.
#' @param start_date Initial date.
#' @param end_date Final date.
#' @param last_n_days Number of last days if no dates are provided.
#' @param api_key AEMET API key.
#' @param df Optional data.frame (as returned by \code{\link{aemet2df}}).
#' @param file Optional input: a file (.csv, .RData or .rds), a vector of
#'   files, or a directory (its .csv/.rds/.RData files are read recursively),
#'   e.g. the \code{out_dir} of \code{\link{aemet2download}}; with
#'   \code{station_ids}, only the files of those stations are read.
#' @param inventory Optional inventory: a data.frame returned by
#'   \code{\link{aemet2inventory}} or the path of a file saved with
#'   \code{aemet2inventory(file = ...)}.
#' @param output_file Optional output file (.RData or .rds).
#' @param verbose Logical.
#' @param control List passed to \code{\link{aemet2df}}.
#'
#' @return An object of class \code{c("ldata", "list")} whose first element is
#'   \code{df} and the remaining elements are \code{\link[fda.usc]{fdata}}
#'   objects.
#'
#' @seealso \code{\link{aemet2download}} for long periods and all stations,
#'   \code{\link{aemet2fdata}}, \code{\link[fda.usc]{ldata}}
#'
#' @examples
#' # Example data shipped with the package (2 stations, 2023-2024)
#' f <- system.file("extdata", "aemet_example.csv", package = "aemet2fdata")
#'
#' ld <- aemet2lfdata(file = f, vars = c("tmed", "tmax", "tmin", "prec"))
#' names(ld)
#' sapply(ld, NROW)     # 4 curves (2 stations x 2 years) in every element
#' ld$df
#' fda.usc::is.ldata(ld)
#'
#' # fda.usc methods for ldata
#' plot(ld$tmed, col = as.integer(factor(ld$df$station_id)))
#' ld2023 <- subset(ld, ld$df$year == 2023)
#' sapply(ld2023, NROW)
#'
#' # With station metadata (coordinates, altitude, WMO id) from the inventory
#' # shipped with the package; aemet2inventory(api_key) downloads a fresh one
#' inv <- system.file("extdata", "inventory.rds", package = "aemet2fdata")
#' ld <- aemet2lfdata(file = f, vars = c("tmed", "prec"), inventory = inv)
#' ld$df
#'
#' \dontrun{
#' # Download from the API
#' api_key <- Sys.getenv("AEMET_API_KEY")
#' inv <- aemet2inventory(api_key = api_key)
#' ld3 <- aemet2lfdata(
#'   station_ids = inv$station_id[1:2],
#'   vars = c("tmed", "prec"),
#'   start_date = "2019-01-01",
#'   end_date = "2020-12-31",
#'   api_key = api_key,
#'   inventory = inv,
#'   output_file = "aemet_ldata.rds"
#' )
#' plot(ld3)
#' }
#' @export
aemet2lfdata <- function(
    station_ids = NULL,
    vars = NULL,
    start_date = NULL,
    end_date = NULL,
    last_n_days = 30,
    api_key = NULL,
    df = NULL,
    file = NULL,
    inventory = NULL,
    output_file = NULL,
    verbose = FALSE,
    control = list()
) {
  
  if (!is.null(station_ids)) station_ids <- as.character(station_ids)
  if (!is.null(df) && !is.null(file)) {
    stop("Use only one input source: either 'df' or 'file'.")
  }
  
  # -------------------------
  # 1. Load data
  # -------------------------
  if (!is.null(df) || !is.null(file)) {
    df_data <- .read_aemet_input(df = df, file = file, station_ids = station_ids)
  } else {
    if (is.null(station_ids)) {
      stop("'station_ids' must be provided when downloading from the API.")
    }
    if (is.null(api_key)) {
      stop("'api_key' must be provided when downloading from the API.")
    }
    df_data <- aemet2df(
      station_ids = station_ids,
      start_date = start_date,
      end_date = end_date,
      last_n_days = last_n_days,
      vars = vars,
      api_key = api_key,
      verbose = verbose,
      control = control
    )
  }
  
  if (!is.data.frame(df_data) || nrow(df_data) == 0L) {
    stop("No data available.",
         if (is.null(df) && is.null(file)) paste0(
           " Check 'station_ids': they must be AEMET station identifiers ",
           "('station_id' in aemet2inventory(), e.g. \"1387\"), not 'wmo_id'."),
         call. = FALSE)
  }
  if (!"fecha" %in% names(df_data)) stop("Missing 'fecha' column.")
  if (!"station_id" %in% names(df_data)) stop("Missing 'station_id' column.")
  
  df_data$fecha <- as.Date(df_data$fecha)
  df_data$station_id <- as.character(df_data$station_id)
  keep <- !is.na(df_data$fecha) & !is.na(df_data$station_id)
  if (!is.null(station_ids)) keep <- keep & df_data$station_id %in% station_ids
  if (!all(keep)) df_data <- df_data[keep, , drop = FALSE]
  rm(keep)
  if (nrow(df_data) == 0L) {
    stop("No data available after filtering by station_ids.")
  }
  
  # -------------------------
  # 2. Variables
  # -------------------------
  numeric_vars <- aemet_metadata$var_name[aemet_metadata$var_type == "numeric"]
  vars_available <- intersect(numeric_vars, names(df_data))
  
  if (is.null(vars)) {
    vars <- vars_available
  } else {
    miss_vars <- setdiff(vars, vars_available)
    if (length(miss_vars) > 0L) {
      warning("Variable(s) not available in the data and dropped: ",
              paste(miss_vars, collapse = ", "))
    }
    vars <- intersect(vars, vars_available)
  }
  if (length(vars) == 0L) stop("No valid numeric variables found.")
  
  # -------------------------
  # 3. Curves: one per station-year (common to all variables)
  # -------------------------
  idx  <- .aemet_curve_index(df_data)
  keys <- idx$keys
  
  # -------------------------
  # 4. Metadata: one row per curve
  # -------------------------
  if (is.null(inventory) && !is.null(api_key)) {
    inventory <- tryCatch(
      aemet2inventory(api_key = api_key, verbose = verbose),
      error = function(e) {
        warning("Inventory could not be downloaded; using metadata from the data.")
        NULL
      }
    )
  }
  inventory <- .aemet_read_inventory(inventory)
  meta_station <- .aemet_station_meta(df_data, unique(keys$station_id), inventory)
  if (all(is.na(meta_station$lon))) {
    message("Station coordinates (lon, lat) not available: ",
            "pass 'inventory' (see aemet2inventory()) or 'api_key'.")
  }
  
  meta_df <- meta_station[match(keys$station_id, meta_station$station_id), ,
                          drop = FALSE]
  meta_df$year <- keys$year
  rownames(meta_df) <- rownames(keys)
  
  # number of days with a record in each curve (<= 365)
  meta_df$n_days <- tabulate(idx$row, nbins = nrow(keys))
  
  # -------------------------
  # 5. Build ldata (fda.usc constructor)
  # -------------------------
  lfd <- lapply(vars, function(v) .aemet_fdata(df_data, v, idx))
  names(lfd) <- vars
  ldat <- ldata(df = meta_df, mfdata = lfd)
  
  .save_aemet_object(ldat, output_file, name = "ldata")
  ldat
}
