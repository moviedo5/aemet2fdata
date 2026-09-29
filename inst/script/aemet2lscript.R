data(aemet)
api_key <- Sys.getenv("AEMET_API_KEY")
# api_key <- "YOUR_API_KEY"
date_ini <- "2025-01-01"
date_end <- "2025-12-31"
# Example 1: from API

ld1 <- aemet2lfdata( 
  station_id = id,
  vars = c("tmed"),
  start_date = date_ini,
  end_date = date_end,
  api_key = api_key
)
sapply(ld1,dim)
names(ld1)
names(ld1$df)
class(ld1)=c("ldata","list")
# # no plot.lfdata(ld1)
plot(ld1, col=2)
plot(ld1$tmed)

#plot(ld1$prec)

# Example 2: from data.frame
fileTest <- "fileTest.csv"
df1 <- aemet2df(
  station_ids = "1387",
  start_date = date_ini,
  end_date = date_end,
  vars = c("tmed","prec"),
  api_key = api_key,
  file= fileTest
)
#fd1 =aemet2fdata(df=df1,station_id = "1387",var="tmed")
#plot(fd1)
inv <- aemet2inventory(api_key = api_key)
ld2 <- aemet2lfdata(df = df1, 
                    vars = c("tmed","prec"),
                    inventory = inv)
sapply(ld2,nrow)
#class(ld2)=c("ldata","list")
plot(ld2)
plot(ld2$tmed)
plot(ld2$prec)                     
#'
# Example 3: from CSV
ld3 <- aemet2lfdata(
  file = fileTest,
  vars = c("tmed","prec"),
  inventory = inv)

plot(ld3)

# Example 4: save output
ld4 <- aemet2lfdata(
  df = df1,
  vars = c("tmed","prec"),
  output_file = "aemet_ldata.rds",
  api_key = api_key
)
plot(ld4)

# Example 4: save output
ld4 <- aemet2lfdata(
  df = df1,
  vars = c("tmed"),
  output_file = "aemet_ldata.rds",
  api_key = api_key
)
plot(ld4)




# replica aemet de fda.usc

###################
library(lubridate)
table(year(df_all$fecha))
table(df_all$station_name)
x=aemet2fdata(df=df_all,var="tmed",station_id=id)
dim(x)
plot(x)
# guardar al final
write.csv2(df_all, "aemet2fdata.csv", row.names = FALSE)

fileTest <- "fileTest.csv"
id <- aemet$df$ind
date_ini <- "1980-01-01"
date_end <- "2009-12-31"
df_all <- aemet2df(
  station_ids = id,
  vars = c("tmed"),
  start_date = "1980-01-01",
  end_date   = "2009-12-31",
  api_key = api_key,
  control = list(
    sleep_pause = 2.5,
    retry_wait = 120,
    max_attempts = 5
  ),
  file = "aemet2fdata.csv"
)
df_all <- Reduce(rbind_fill, dfs)

#fd1 =aemet2fdata(df=df1,station_id = "1387",var="tmed")
#plot(fd1)
inv <- aemet2inventory(api_key = api_key)
ld2 <- aemet2lfdata(df = df1, 
                    vars = c("tmed","prec"),
                    inventory = inv)

##############################################################3
# conocer fechas históricas tentativas 
check_station_valid <- function(st, api_key,
                                date_ini = "1980-01-01",
                                date_end = "2009-12-31") {
  
  test_date <- function(date) {
    
    df <- tryCatch(
      aemet2df(
        station_ids = st,
        start_date = date,
        end_date   = date,
        api_key = api_key,
        control = list(max_attempts = 2, sleep_pause = 0)
      ),
      error = function(e) NULL
    )
    
    return(!is.null(df) && nrow(df) > 0)
  }
  
  ok_ini <- test_date(date_ini)
  ok_end <- test_date(date_end)
  
  return(ok_ini & ok_end)
}

filter_stations <- function(station_ids, api_key,
                            date_ini = "1980-01-01",
                            date_end = "2009-12-31") {
  
  valid <- c()
  
  for (st in station_ids) {
    
    cat("Checking:", st, "\n")
    
    ok <- check_station_valid(st, api_key, date_ini, date_end)
    
    if (ok) {
      valid <- c(valid, st)
    }
    
    Sys.sleep(1)
  }
  
  valid
}
id <- aemet$df$ind

date_ini <- "1980-01-01"
date_end <- "2009-12-31"

id_valid <- filter_stations(
  id,
  api_key,
  date_ini = date_ini,
  date_end = date_end
)
length(id_valid)
length(id)


df_all <- NULL

date_end <- 2004
date_ini <- 2004
for (year in date_ini:date_end) {
  
  cat("Downloading year:", year, "\n")
  
  df_year <- aemet2df(
    station_ids = id_valid,
    start_date = paste0(year, "-01-01"),
    end_date   = paste0(year, "-12-31"),
    vars = c("tmed"),
    api_key = api_key,
    control = list(
      sleep_pause = 2.5,
      retry_wait  = 3,
      max_attempts = 5
    ),
    verbose = TRUE
  )
  
  # acumular
  df_all <- rbind_fill(df_all, df_year)
#   
  # pausa entre años (MUY importante)
  Sys.sleep(5)
}
dfaaa33 = rbind(dfaaa22,df_all)
#df2008_2009=df_all
#save(df_all,file="aemet2008_2009.RData")
#########################
library(lubridate)
table(year(df_all$fecha))
id_valid2 = unique(names(table(df_all$station_id)))
length(id_valid)
length(id_valid2)
x <- aemet2fdata(
  df = df_all,
  var = "tmed"
)

ld <- aemet2lfdata(
  df = df_all,
  vars = "tmed",
  inventory = inv
)
sapply(ld,dim)

x=aemet2fdata(df=df_all,var="tmed",station_id=id_valid2[1])
lx=aemet2lfdata(df=df_all,var="tmed",station_id=id_valid2,api_key = api_key)
sapply(lx,dim)
col=ifelse(lx$df$lat<31,2,4)
plot(lx,col=col)
plot(fdata.deriv(na.omit(lx[[2]])),col=col)
na.action(na.omit(lx[[2]]))
dim(lx$df)
dim(lx$tmed)
lx$df[118,]
lx$tmed$data[118,] # verificar la falta de datos,
# hacer otra consulta y comprobar q no se tienen datos
# plantear un scrip, por estación y otro por años y guardar toda
# esa info en tablas 
# preparar shiny y pasar a omie o meteogalicia
# ejemplo para interpolar o meter npsfda con Ruben y verificar consultando
# con valores reales 
#########################
df_all <- aemet2df(
  station_ids = id_valid,
  start_date = date_ini,
  end_date   = date_end,
  api_key = api_key
)


# inv <- aemet2inventory(api_key)
# idf <- inv$station_id
id <- aemet$df$ind
hist <- build_aemet_history(id, api_key, 
                            start_date = "1980-01-01",
                            end_date   = "2009-12-31")

meta_full <- merge(inv, hist, by = "station_id", all.x = TRUE)


inv <- aemet2inventory(api_key)

hist <- build_aemet_history(inv$station_id, api_key)

meta_full <- merge(inv, hist, by = "station_id", all.x = TRUE)


#Guárdalo en:
#  inst/extdata/aemet_station_history.csv
# o en:
#   data/aemet_station_history.rda
data(aemet_station_history)
#En aemet2lfdata:
meta_df <- merge(meta_df, 
                 aemet_station_history, 
                 by = "station_id", 
                 all.x = TRUE)






################################################################################
api_key <- Sys.getenv("AEMET_API_KEY")
# ' DESCARGA HISTORICA DE DATOS POR ESTACION
# para cada estación:
#   
#  Prueba si hay datos en 2025
# Si NO hay, descarta estación
# Si SÍ hay, empieza a retroceder en bloques de 6 meses
# Cuando un bloque falla, para
# Guarda UN CSV por estación con todo su histórico

build_aemet_by_station <- function(
    station_ids,
    api_key,
    out_dir = "aemet_csv",
    start_date = "1980-01-01",
    end_date   = "2009-12-31",
    sleep_pause = 2,
    retry_wait = 120,
    max_attempts = 5,
    verbose = TRUE
) {
  
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  
  results <- list()
  
  for (st in station_ids) {
    
    if (verbose) cat("\n=== Station:", st, "===\n")
    
    file_out <- file.path(out_dir, paste0(st, ".csv"))
    
    #----------------------------------
    # Saltar si ya existe (cache)
    #----------------------------------
    if (file.exists(file_out)) {
      if (verbose) cat("Already exists → skip\n")
      next
    }
    
    #----------------------------------
    # Descargar usando TU función
    #----------------------------------
    df_st <- tryCatch(
      aemet2df(
        station_ids = st,
        start_date = start_date,
        end_date   = end_date,
        api_key = api_key,
        verbose = verbose,
        control = list(
          sleep_pause = sleep_pause,
          retry_wait = retry_wait,
          max_attempts = max_attempts
        )
      ),
      error = function(e) NULL
    )
    
    #----------------------------------
    # Validación
    #----------------------------------
    if (is.null(df_st) || nrow(df_st) == 0) {
      if (verbose) cat("No data → skip\n")
      next
    }
    
    #----------------------------------
    # Opcional: filtrar años incompletos
    #----------------------------------
    years <- format(df_st$fecha, "%Y")
    tab <- table(years)
    
    valid_years <- names(tab[tab >= 300])  # tolerancia
    
    df_st <- df_st[years %in% valid_years, ]
    
    if (nrow(df_st) == 0) {
      if (verbose) cat("No valid years → skip\n")
      next
    }
    
    #----------------------------------
    # Guardar CSV
    #----------------------------------
    write.csv2(
      df_st,
      file = file_out,
      row.names = FALSE,
      fileEncoding = "UTF-8"
    )
    
    if (verbose) cat("Saved:", file_out, "\n")
    
    results[[st]] <- df_st
    
    Sys.sleep(sleep_pause)
  }
  
  invisible(results)
}
#############
inv <- aemet2inventory(api_key)
ids <- inv$station_id
#length(ids)
library(fda.usc)
library(aemet2fdata)
data(aemet)
ids <- aemet$df$ind
# descarga los datos de aemet de fda.usc, faltaria hacer la media para replicarla
#build_aemet_by_station(  station_ids = ids,  api_key = api_key)
#####################
################################################################################
# 2. Filtrar estaciones válidas en los extremos del periodo
id_valid <- filter_stations(
  station_ids = ids,
  api_key = api_key,
  date_ini = "1980-01-01",
  date_end = "2025-12-31"
)

files_done <- list.files("aemet_csv", pattern = "\\.csv$", full.names = FALSE)
ids_desc <- tools::file_path_sans_ext(files_done)
ids_falta <- setdiff(id_valid, ids_desc)
length(ids)
length(id_valid)
length(ids_falta)
length(ids);length(id_valid);length(ids_falta)

build_aemet_by_station(
  station_ids = ids_falta,
  api_key = api_key,
  start_date = "1925-01-01",
  end_date   = "2025-12-31"
)

files_done2 <- list.files("aemet_csv", pattern = "\\.csv$", full.names = FALSE)
length(files_done2)
################################################################################
# falta leer lso 84 CSV y crear un fdata conjunto con 84X30 años por ejemplo
################################################################################


library(aemet2fdata)
api_key <- Sys.getenv("AEMET_API_KEY")
api_key <- Sys.getenv("AEMET_API_KEY")

# 0) quick test first (1 month) to confirm AEMET accepts the window
aemet2download("2025-01-01", "2025-01-31", api_key = api_key,
               out_dir = "aemet_prueba", vars = c("tmed","tmin","tmax","prec","sol"))

# 1) everything: 1976-2025 (if it stops, run it again)
log <- aemet2download(
  start_date = "1926-01-01", end_date = "2025-12-31",
  api_key = api_key, out_dir = "aemet_daily",
  vars = c("tmed", "tmin", "tmax", "prec", "sol")
)
table(log$status)
list.files("aemet_daily/1387")
table(log$status)

ld  <- aemet2lfdata(file = "aemet_daily", inventory = "inventory.rds")
ld3 <- subset(ld, ld$df$n_days >= 365)          # solo años completos

# Estaciones con TODOS los años de 'years' completos
full_stations <- function(x, years) {
  x  <- subset(x, x$df$year %in% years)
  ny <- table(x$df$station_id)
  subset(x, x$df$station_id %in% names(ny)[ny == length(years)])
}

rg    <- range(ld3$df$year)                     # 1926 2025
ld100 <- full_stations(ld3, rg[1]:rg[2])        # 100 años
ld50  <- full_stations(ld3, 1976:2025)          # 50 años
ld40  <- full_stations(ld3, 1986:2025)          # 40 años

sapply(ld100, dim); table(ld100$df$station_id)
sapply(ld50,  dim); length(unique(ld50$df$station_id))
sapply(ld40,  dim); length(unique(ld40$df$station_id))

saveRDS(ld100, "aemet_ldata_1926_2025_Full.rds")
saveRDS(ld50,  "aemet_ldata_1976_2025_Full.rds")
saveRDS(ld40,  "aemet_ldata_1986_2025_Full.rds")


table(ld100$df$year)
table(ld50$df$year)
table(ld40$df$year)
table(ld40$df$station_id)

# Curva media anual por año
a1 <- fda.usc:::func.mean.formula(tmed ~ year, data = ld40)
plot(a1[c(1, 21, 40)], col = 2:4)               # 1976, 2000, 202

a1 <- fda.usc:::func.mean.formula(tmed ~ station_id, data = ld40)
dim(a1)
plot(a1, col = grey((1:59)/59))
o1<-outliers.depth.pond(a1,nb=11,draw=T)
o1$outliers
summary(ld40$df)

plot(a1[c(1, 25, 56)], col = 2:4)               # 1976, 2000, 2025
a1 <- fda.usc:::func.mean.formula(tmed ~ year, data = ld100)
dim(a1)
plot(a1, col = )               # 1976, 2000, 2025



aa<-ld40$tmed[ld40$df$station_id==ld40$df$station_id[1]]
plot(ts(as.numeric(t(aa$data))[1:(365*10)]))

# # 2) ldata: one curve per station-year, with lon/lat from your inventory.rds
ld  <- aemet2lfdata(file = "aemet_daily", inventory = "inventory.rds")
sapply(ld,dim)
#ld2 <- aemet2lfdata(file = "aemet_daily", station_ids = c("1387", "B228"), inventory = "inventory.rds")   
# only reads those stations' files
ld3 <- subset(ld, ld$df$n_days >= 365)      # complete years only
sapply(ld3,dim)
# saveRDS(ld, "aemet_ldata_1976_2025.rds")
# 
# # stations with all 50 years
rg <- diff(range(ld3$df$year))+1

tsta   <- table(ld3$df$station_id)
tyear   <- table(ld3$df$year)
tsta
tyear





ld50 <- subset(ld3, ld3$df$station_id %in% names(ny)[ny == RG])
length(table(ld3$df$station_id))
saveRDS(ld3, "aemet_ldata_1976_2025.rds")
dim(ld3)$sol)
summary(ld3$df)
table(ld3$df$station_id=="1387")
iyear = ld3$df$year==1977
istat =names(which(table(ld$df$station_id)==50))
ld4 = ld[ld$df$station_id %in% istat,row=T]
table(ld4$df$year)
sapply(ld4,dim)
saveRDS(ld4, "aemet_ldata_1976_2025_Full.rds")
plot(ld4$prec[iyear][1:11])
plot(ld3$tmax[iyear][1:111])
plot(ld3$tmax[iyear][1:111])
a1=fda.usc:::func.mean.formula(tmed~year,data=ld4)
plot(a1[c(1,25,30)],col=c(2:4))
library(fda.usc)
library(aemet2fdata)
a1=fda.usc:::func.mean.formula(tmed~year,data=ld4)

plot(a1[c(1,25,30)],col=c(2:4))
 
a1=fda.usc:::func.mean.formula(tmax~station_id,data=ld4)
plot(a1)
iyear=ld40$df$year==2025
dcor.xy(ld40$tmed[iyear],ld40$sol[iyear])
dcor.xy(ld4$tmed[iyear],ld4$df$altitude[iyear])
dcor.xy(ld4$sol[iyear],ld4$df$altitude[iyear])


###################ç
# ldata "serie larga": 1 fila = 1 estación, columnas = año_día concatenados
ldata_ts <- function(x, vars = setdiff(names(x), "df")) {
  o   <- order(x$df$station_id, x$df$year)
  df  <- x$df[o, ]
  st  <- unique(df$station_id)
  yrs <- sort(unique(df$year))
  nS  <- length(st); nY <- length(yrs); nD <- 365L
  stopifnot(nrow(df) == nS * nY,
            all(table(df$station_id) == nY))          # panel balanceado
  
  lab <- sprintf("%d_%03d", rep(yrs, each = nD), rep(seq_len(nD), nY))
  tt  <- rep(yrs, each = nD) + (rep(seq_len(nD), nY) - 1) / nD
  
  to_ts <- function(M) {
    # filas de M: estación (lenta) x año (rápido); A[año, estación, día]
    A  <- array(M[o, , drop = FALSE], c(nY, nS, nD))
    mm <- t(matrix(aperm(A, c(3, 1, 2)), ncol = nS))  # día rápido, luego año
    dimnames(mm) <- list(st, lab)
    mm
  }
  
  mf <- lapply(vars, function(v) {
    fd <- fdata(to_ts(x[[v]]$data), argvals = tt,
                rangeval = c(min(yrs), max(yrs) + 1))
    fd$names$main <- v
    colnames(fd$data) <- lab
    fd
  })
  names(mf) <- vars
  
  # metadatos por estación (sin year); n_days = total de días con dato
  first <- !duplicated(df$station_id)
  dfs   <- df[first, setdiff(names(df), c("year", "n_days"))]
  dfs$n_days  <- as.vector(tapply(df$n_days, df$station_id, sum)[st])
  dfs$year_ini <- min(yrs); dfs$year_fin <- max(yrs)
  rownames(dfs) <- st
  
  ldata(dfs, mfdata = mf)
}

ld40    <- full_stations(ld3, 1986:2025)
ld40ts  <- ldata_ts(ld40)
saveRDS(ld40, "aemet_ldata_1986_2025_Full.rds")
saveRDS(ld40ts,"aemet_ldata_ts_1986_2025.rds")
sapply(ld40ts, dim)                  # 59 x 14600 en cada variable

#plot(ld40ts$tmax[c(1,2)])    
plot(ld40ts$tmax[c("1387")])    # una estación, 40 años seguidos
saveRDS(ld40ts, "aemet_ldata_ts_1986_2025.rds")
names(ld40ts)
plot(ld40ts$tmax[c("1387")])    # una estación, 40 años seguidos
plot(ld40ts$tmax[6:7])    # A coruña, santiago
plot(ld40ts$tmin[6:7])    # A coruña, santiago
plot(ld40ts$prec[6:7])    # A coruña, santiago
plot(ld40ts$sol[6:7])    # A coruña, santiago
plot(ld40ts$sol[6]-ld40ts$sol[7])    # A coruña, santiago
plot(ld40ts$prec[6]-ld40ts$prec[7])    # A coruña, santiago


lines(ld40ts$tmin[c("1387")],col=3)    # una estación, 40 años seguidos
lines(ld40ts$tmed[c("1387")],col=4)    # una estación, 40 años seguidos
plot(ld40ts$tmax[c("1387")]-ld40ts$tmin[c("1387")])    # una estación, 40 años seguidos
plot(ld40ts$tmax[c("1387")]-ld40ts$tmed[c("1387")])    # una estación, 40 años seguidos

