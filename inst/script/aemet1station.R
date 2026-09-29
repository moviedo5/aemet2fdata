# =====================================================================
# AEMET: daily history for one station -> CSV -> annual functional curves
# Natural half-year windows: 1 Jan-30 Jun and 1 Jul-31 Dec
# =====================================================================

library(fda.usc)
library(aemet2fdata)

api_key <- Sys.getenv("AEMET_API_KEY")

station_id <- "1387"
start_date <- "202-01-01"
end_date <- "2025-12-31"
out_dir <- "aemet_csv"

# ---- 1. Download one CSV per station ---------------------------------
# aemet2csv() uses natural half-year windows. With reverse = TRUE the
# requests are made from the most recent semester backwards.
# Existing CSV files are skipped unless overwrite = TRUE.
log <- aemet2csv(
  station_ids = station_id,
  start_date = start_date,
  end_date = end_date,
  api_key = api_key,
  out_dir = out_dir,
  reverse = TRUE
)

print(log)

csv_file <- file.path(out_dir, paste0(station_id, ".csv"))
if (!file.exists(csv_file)) 
  stop("Station CSV was not created: ", csv_file)

# Several stations can be downloaded in the same way, for example:
# aemet2csv(
#   station_ids = c("1387", "B228", "0076"),
#   start_date = start_date,
#   end_date = end_date,
#   api_key = api_key,
#   out_dir = out_dir,
#   reverse = TRUE
# )

# ---- 2. Station inventory ---------------------------------------------
# Keep inventory.rds as a local development file if desired. If it does
# not exist, obtain the inventory from AEMET OpenData for this run.
if (file.exists("inventory.rds")) {
  inv <- readRDS("inventory.rds")
} else {
  inv <- aemet2inventory(api_key = api_key)
}

# ---- 3. Annual functional curves --------------------------------------
# One curve = one station-year, 365 points; 29 February is removed.
vars <- c(
  "tmed", "tmin", "tmax", "prec", "sol",
  "hrMedia", "velmedia", "presMax", "presMin"
)

ld <- aemet2lfdata(
  file = csv_file,
  vars = vars,
  inventory = inv
)

sapply(ld, dim)
head(ld$df)
# plot(ld)

# Percentage of missing functional observations by variable.
na_pct <- sapply(ld[-1], function(f) round(100 * mean(is.na(f$data)), 1))
print(na_pct)

# ---- 4. Complete years -------------------------------------------------
# n_days == 365 means that the station-year contains all 365 calendar
# records after removing 29 February. It does not guarantee that every
# variable has 365 non-missing measurements.
ld_days <- subset(ld, ld$df$n_days >= 365)

# If the analysis requires complete mean-temperature curves, filter them
# explicitly using the fdata matrix.
ok_tmed <- rowSums(!is.na(ld_days$tmed$data)) == 365L
ld_tmed <- subset(ld_days, ok_tmed)

# ---- 5. Plot ------------------------------------------------------------
plot(ld_tmed$tmed,col = hcl.colors(nrow(ld_tmed$df), "Blue-Red 3"),
  main = paste(station_id, "- annual mean-temperature curves"))
