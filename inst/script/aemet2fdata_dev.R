# =====================================================================
# aemet2fdata 0.2.0+ - development / validation workflow
# Run from the package root when local files such as inventory.rds are used.
# =====================================================================

library(aemet2fdata)
library(fda.usc)

api_key <- Sys.getenv("AEMET_API_KEY")

# ---------------------------------------------------------------------
# 1. Local example shipped with the package
# ---------------------------------------------------------------------
f <- system.file("extdata", "aemet_example.csv", package = "aemet2fdata")

fd_tmed <- aemet2fdata(file = f, var = "tmed")
dim(fd_tmed)
rownames(fd_tmed$data)
plot(fd_tmed, col = rep(c(2, 4), each = 2))
legend("topleft", legend = c("1387", "B228"), col = c(2, 4), lty = 1)
plot(func.mean(fd_tmed), main = "Mean curve", lwd = 2)

ld0 <- aemet2lfdata(file = f, vars = c("tmed", "tmax", "tmin", "prec"))
names(ld0)
sapply(ld0, NROW)
ld0$df
is.ldata(ld0)

ld_coruna <- subset(ld0, ld0$df$station_id == "1387")
sapply(ld_coruna, NROW)
plot(ld0$tmax, col = as.integer(factor(ld0$df$station_id)),
     main = "Maximum temperature")

# ---------------------------------------------------------------------
# 2. Inventory and simple API / file workflows
# ---------------------------------------------------------------------
inventory_file <- "inventory.rds"
if (file.exists(inventory_file)) {
  inv <- readRDS(inventory_file)
} else {
  inv <- aemet2inventory(api_key = api_key, file = inventory_file)
}
head(inv)

# API -> data.frame -> CSV
file_test <- "fileTest.csv"
df1 <- aemet2df(
  station_ids = "1387",
  start_date = "2025-01-01",
  end_date = "2025-12-31",
  vars = c("tmed", "prec"),
  api_key = api_key,
  file = file_test
)

# data.frame -> ldata
ld1 <- aemet2lfdata(df = df1, vars = c("tmed", "prec"), inventory = inv)
sapply(ld1, NROW)
plot(ld1)
# plot(ld1$tmed);plot(ld1$prec)

# CSV -> ldata
ld2 <- aemet2lfdata(file = file_test, vars = c("tmed", "prec"), inventory = inv)
plot(ld2)

# API -> ldata. Note the plural station_ids / vars interface.
ld3 <- aemet2lfdata(
  station_ids = c("1387", "B228"),
  vars = c("tmed", "prec"),
  start_date = "2018-01-01",
  end_date = "2020-12-31",
  api_key = api_key,
  inventory = inv,
  output_file = "aemet_ldata.rds"
)
sapply(ld3, NROW)

# ---------------------------------------------------------------------
# 3. IDs: keep the two populations separate
# ---------------------------------------------------------------------
data(aemet)
ids_fdausc <- unique(as.character(aemet$df$ind))
ids_inventory <- unique(as.character(inv$station_id))

length(ids_fdausc)   # stations in the fda.usc::aemet reference data
length(ids_inventory) # stations in the current AEMET inventory

# ---------------------------------------------------------------------
# 4. One CSV per station: aemet2csv()
# ---------------------------------------------------------------------
# This replaces the old build_aemet_by_station() helper.
# Existing CSV files are skipped automatically when overwrite = FALSE.
# Windows are natural half-years: Jan-Jun and Jul-Dec.
# reverse = TRUE searches from the most recent period backwards.

log_csv <- aemet2csv(
  station_ids = ids_fdausc,
  start_date = "2006-01-01",
  end_date = "2025-12-31",
  api_key = api_key,
  out_dir = "aemet_csv",
  reverse = TRUE,
  stop_nodata = 10,
  overwrite = FALSE
)
table(log_csv$status, useNA = "ifany")

# Read all station CSVs directly; no manual rbind/Reduce is needed.
ld_csv <- aemet2lfdata(
  file = "aemet_csv",
  vars = c("tmed", "tmin", "tmax", "prec", "sol"),
  inventory = inv
)
sapply(ld_csv, dim)

# ---------------------------------------------------------------------
# 5. Optional boundary pre-check
# ---------------------------------------------------------------------
# Use only when you explicitly want stations with a record on BOTH exact
# boundary dates. It is a fast heuristic and can reject a station if one of
# those particular days is missing. It is not needed by aemet2csv().

check_station_valid <- function(st, api_key,
                                date_ini = "1980-01-01",
                                date_end = "2025-12-31") {
  test_date <- function(date) {
    z <- tryCatch(
      aemet2df(
        station_ids = st,
        start_date = date,
        end_date = date,
        api_key = api_key,
        control = list(max_attempts = 2, sleep_pause = 0)
      ),
      error = function(e) NULL
    )
    !is.null(z) && nrow(z) > 0L
  }
  test_date(date_ini) && test_date(date_end)
}

filter_stations <- function(station_ids, api_key,
                            date_ini = "1980-01-01",
                            date_end = "2025-12-31",
                            sleep_pause = 1) {
  station_ids <- unique(as.character(station_ids))
  ok <- logical(length(station_ids))
  for (i in seq_along(station_ids)) {
    cat("Checking:", station_ids[i], "\n")
    ok[i] <- check_station_valid(station_ids[i], api_key, date_ini, date_end)
    Sys.sleep(sleep_pause)
  }
  station_ids[ok]
}

# Example for all stations in the current inventory:
# ids_valid <- filter_stations(ids_inventory, api_key,
#                              date_ini = "1980-01-01",
#                              date_end = "2025-12-31")
# log_valid <- aemet2csv(
#   station_ids = ids_valid,
#   start_date = "1925-01-01",
#   end_date = "2025-12-31",
#   api_key = api_key,
#   out_dir = "aemet_csv",
#   reverse = TRUE
# )

# ---------------------------------------------------------------------
# 6. Bulk download: one file per station-year
# ---------------------------------------------------------------------
# This is the preferred route when the goal is ALL stations over a fixed
# long period. With station_ids = NULL, AEMET's all-stations service is used.
# Do not run this and aemet2csv() for the same purpose unless both layouts
# are genuinely needed.

# Quick test
log_test <- aemet2download(
  start_date = "2025-01-01",
  end_date = "2025-01-31",
  api_key = api_key,
  out_dir = "aemet_prueba",
  vars = c("tmed", "tmin", "tmax", "prec", "sol")
)
table(log_test$status)

# Long download; resumable by repeating exactly the same call.
# log_bulk <- aemet2download(
#   start_date = "1926-01-01",
#   end_date = "2025-12-31",
#   api_key = api_key,
#   out_dir = "aemet_daily",
#   vars = c("tmed", "tmin", "tmax", "prec", "sol")
# )
# table(log_bulk$status)

# ---------------------------------------------------------------------
# 7. Build and filter the long ldata object
# ---------------------------------------------------------------------
# Requires aemet_daily/ produced by aemet2download().
# ld <- aemet2lfdata(file = "aemet_daily", inventory = inv)
# sapply(ld, dim)

# n_days is the number of daily records in the station-year, not the number
# of non-missing values of every meteorological variable.
complete_records <- function(x) {  subset(x, x$df$n_days == 365L)}

complete_curves <- function(x, vars = setdiff(names(x), "df")) {
  ok <- x$df$n_days == 365L
  for (v in vars) {
    ok <- ok & rowSums(!is.na(x[[v]]$data)) == 365L
  }
  subset(x, ok)
}

full_stations <- function(x, years) {
  z <- subset(x, x$df$year %in% years)
  ny <- table(z$df$station_id)
  ids <- names(ny)[ny == length(years)]
  subset(z, z$df$station_id %in% ids)
}

# Structural completeness only:
# ld_complete <- complete_records(ld)
# ld40  <- full_stations(ld_complete, 1986:2025)
#
# sapply(ld40, dim)
# length(unique(ld40$df$station_id))
# saveRDS(ld40,  "aemet_ldata_1986_2025_Full.rds")

# If analyses require no NA in all selected variables, use instead:
# ld_complete_values <- complete_curves(
#   ld, vars = c("tmed", "tmin", "tmax", "prec", "sol")
# )

# ---------------------------------------------------------------------
# 8. Exploratory fda.usc analyses
# ---------------------------------------------------------------------
# The formula method below is currently accessed with :::; keep this in a
# development script, not in package code.
#
# a_year <- fda.usc:::func.mean.formula(tmed ~ year, data = ld40)
# dim(a_year)
# plot(a_year[c(1, 21, 40)], col = 2:4)  # 1986, 2006, 2025
#
# a_station <- fda.usc:::func.mean.formula(tmed ~ station_id, data = ld40)
# dim(a_station)
# plot(a_station, col = gray.colors(nrow(a_station)))
#
# o1 <- outliers.depth.pond(a_station, nb = 11, draw = TRUE)
# o1$outliers
#
# i2025 <- ld40$df$year == 2025
# dcor.xy(ld40$tmed[i2025], ld40$sol[i2025])
# dcor.xy(ld40$tmed[i2025], ld40$df$altitude[i2025])

# ---------------------------------------------------------------------
# 9. Convert a balanced ldata panel to one long curve per station
# ---------------------------------------------------------------------
ldata_ts <- function(x, vars = setdiff(names(x), "df")) {
  o <- order(x$df$station_id, x$df$year)
  df <- x$df[o, , drop = FALSE]
  st <- unique(df$station_id)
  yrs <- sort(unique(df$year))
  nS <- length(st)
  nY <- length(yrs)
  nD <- 365L

  stopifnot(nrow(df) == nS * nY, all(table(df$station_id) == nY))

  lab <- sprintf("%d_%03d", rep(yrs, each = nD), rep(seq_len(nD), nY))
  tt <- rep(yrs, each = nD) + (rep(seq_len(nD), nY) - 1) / nD

  to_ts <- function(M) {
    A <- array(M[o, , drop = FALSE], c(nY, nS, nD))
    mm <- t(matrix(aperm(A, c(3, 1, 2)), ncol = nS))
    dimnames(mm) <- list(st, lab)
    mm
  }

  mf <- lapply(vars, function(v) {
    nm <- x[[v]]$names
    nm$xlab <- "year"
    fd <- fdata(to_ts(x[[v]]$data), argvals = tt,
                rangeval = c(min(yrs), max(yrs) + 1), names = nm)
    colnames(fd$data) <- lab
    fd
  })
  names(mf) <- vars

  first <- !duplicated(df$station_id)
  dfs <- df[first, setdiff(names(df), c("year", "n_days")), drop = FALSE]
  dfs$n_days <- as.vector(tapply(df$n_days, df$station_id, sum)[st])
  dfs$year_ini <- min(yrs)
  dfs$year_fin <- max(yrs)
  rownames(dfs) <- st

  ldata(dfs, mfdata = mf)
}

# Example:
# ld40 <- full_stations(complete_records(ld), 1986:2025)
# ld40ts <- ldata_ts(ld40)
# sapply(ld40ts, dim)  # one row per station, 40*365 columns per fdata
# saveRDS(ld40ts, "aemet_ldata_ts_1986_2025.rds")
#
# plot(ld40ts$tmax["1387"])
# plot(ld40ts$tmax[6:7])
# plot(ld40ts$tmin[6:7])
# plot(ld40ts$prec[6:7])
# plot(ld40ts$sol[6:7])
# plot(ld40ts$tmax["1387"] - ld40ts$tmin["1387"])
