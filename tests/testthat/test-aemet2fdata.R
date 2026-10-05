# Offline tests: bundled example (1387 A Coruña, B228 Palma, 2023-2024)
f   <- system.file("extdata", "aemet_example.csv", package = "aemet2fdata")
inv <- system.file("extdata", "inventory.rds", package = "aemet2fdata")

test_that("aemet2fdata(): one curve per station-year with 365 days", {
  fd <- aemet2fdata(file = f, var = "tmed")
  expect_s3_class(fd, "fdata")
  expect_equal(dim(fd$data), c(4L, 365L))
  expect_equal(rownames(fd$data), c("1387_2023", "1387_2024", "B228_2023", "B228_2024"))
})

test_that("aemet2lfdata(): df and fdata rows are aligned", {
  ld <- suppressMessages(aemet2lfdata(file = f, vars = c("tmed", "prec")))
  expect_s3_class(ld, "ldata")
  expect_identical(rownames(ld$df), rownames(ld$tmed$data))
  expect_identical(rownames(ld$df), rownames(ld$prec$data))
  expect_equal(ld$df$n_days, rep(365L, 4))
})

test_that("the bundled inventory provides coordinates", {
  ld <- aemet2lfdata(file = f, vars = "tmed", inventory = inv)
  expect_false(anyNA(ld$df$lon))
  expect_false(anyNA(ld$df$lat))
  expect_equal(round(ld$df$lat[ld$df$station_id == "1387"][1], 2), 43.37)
})

test_that("leap years: 29 February is removed and column 60 is 1 March", {
  d <- data.frame(fecha = seq(as.Date("2024-01-01"), as.Date("2024-12-31"), by = "day"),
                  station_id = "X")
  d$tmed <- as.numeric(format(d$fecha, "%j"))       # day of year
  fd <- aemet2fdata(df = d, var = "tmed")
  expect_equal(ncol(fd$data), 365L)
  expect_equal(unname(fd$data[1, 59]), 59)           # 28 February
  expect_equal(unname(fd$data[1, 60]), 61)           # 1 March 2024 (day 61)
})

test_that("overlapping input files do not duplicate days", {
  ld <- NULL
  expect_warning(ld <- suppressMessages(aemet2lfdata(file = c(f, f), vars = "tmed")),
                 "duplicated")
  expect_equal(ld$df$n_days, rep(365L, 4))
})

test_that("CSV keeps accents and the letter n with tilde whatever the locale", {
  tf <- tempfile(fileext = ".csv")
  x <- data.frame(fecha = as.Date("2024-01-01"), station_id = "1387",
                  station_name = "A CORUÑA", tmed = 12.5, stringsAsFactors = FALSE)
  aemet2fdata:::.write_csv_utf8(x, tf)
  y <- aemet2fdata:::.read_csv_utf8(tf, colClasses = c(station_id = "character"))
  expect_identical(y$station_name, "A CORUÑA")
  expect_identical(y$station_id, "1387")
  expect_equal(y$tmed, 12.5)
})

test_that("AEMET text values and coordinates are parsed", {
  expect_equal(aemet2fdata:::clean_var(c("12,5", "Ip", "Varias", "")), c(12.5, 0.1, NA, NA))
  expect_equal(round(aemet2fdata:::dms_to_dd(c("432157N", "082517W")), 4),
               c(43.3658, -8.4214))
})
