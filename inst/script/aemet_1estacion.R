# =====================================================================
#  AEMET: historia diaria de UNA estación -> CSV -> curvas anuales
#  Descarga por semestres (1 ene-30 jun, 1 jul-31 dic): 2 peticiones/año
#  100 años = 200 peticiones como máximo (menos si la estación es más joven)
# =====================================================================
library(fda.usc)
library(aemet2fdata)
source("apikey.dat")                     # define api_key (fuera de git)

# ---- 1. Descarga: aemet_csv/1387.csv (UTF-8, data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABIAAAASCAYAAABWzo5XAAAAbElEQVR4Xs2RQQrAMAgEfZgf7W9LAguybljJpR3wEse5JOL3ZObDb4x1loDhHbBOFU6i2Ddnw2KNiXcdAXygJlwE8OFVBHDgKrLgSInN4WMe9iXiqIVsTMjH7z/GhNTEibOxQswcYIWYOR/zAjBJfiXh3jZ6AAAAAElFTkSuQmCC";" y decimal ",") -------
# Si el fichero ya existe se salta; si falla alguna ventana no se escribe
# y basta con volver a ejecutar.
log <- aemet2csv("1387", start_date = "1926-01-01", end_date = "2025-12-31",
                 api_key = api_key, out_dir = "aemet_csv")
log                                      # status, peticiones, filas, primera/última fecha
# Varias estaciones: aemet2csv(c("1387", "B228", "0076"), ...)

# ---- 2. Curvas anuales (1 curva = 1 año, 365 días, sin 29-feb) -------
vars <- c("tmed", "tmin", "tmax", "prec", "sol",
          "hrMedia", "velmedia", "presMax", "presMin")
ld <- aemet2lfdata(file = "aemet_csv/1387.csv", vars = vars,
                   inventory = "inventory.rds")
sapply(ld, dim)                          # nº años x 365
head(ld$df)                              # year, n_days, lon, lat, altitud...

# % de NA por variable (sol y presión suelen empezar más tarde)
sapply(ld[-1], function(f) round(100 * mean(is.na(f$data)), 1))

# Solo años completos y gráfico de la temperatura media
ld <- subset(ld, ld$df$n_days >= 365)
plot(ld$tmed, col = hcl.colors(nrow(ld$df), "Blue-Red 3"),
     main = "1387 A Coruña - tmed por año")
