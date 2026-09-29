# =========================================
# utils-csv.R  (CSV UTF-8 independiente del locale)
# =========================================

#' Write a data.frame as CSV2 (sep ";", dec ","), UTF-8 with BOM, whatever the
#' locale: strings are converted to UTF-8 and written as bytes, so accents and
#' "ñ" are kept (and Excel opens it correctly thanks to the BOM).
#' @noRd
.write_csv_utf8 <- function(x, file) {
  col_txt <- lapply(x, function(v) {
    if (inherits(v, "Date")) {
      out <- as.character(v)
    } else if (is.numeric(v)) {
      out <- sub(".", ",", as.character(v), fixed = TRUE)
    } else {
      v <- enc2utf8(as.character(v))
      out <- paste0("\"", gsub("\"", "\"\"", v, fixed = TRUE), "\"")
    }
    out[is.na(v)] <- "NA"
    out
  })
  head <- paste0("\"", enc2utf8(names(x)), "\"", collapse = ";")
  body <- if (nrow(x) > 0L) do.call(paste, c(col_txt, sep = ";")) else character(0)
  con <- file(file, open = "wb")
  on.exit(close(con))
  writeBin(as.raw(c(0xEF, 0xBB, 0xBF)), con)                 # BOM UTF-8
  writeLines(c(head, body), con, sep = "\r\n", useBytes = TRUE)
  invisible(file)
}

#' Read a CSV2 written by .write_csv_utf8() or write.csv2(fileEncoding = "UTF-8")
#' (with or without BOM) without re-encoding: strings come back as UTF-8.
#' @noRd
.read_csv_utf8 <- function(file, colClasses = NA) {
  raw <- readBin(file, "raw", file.info(file)$size)
  if (length(raw) >= 3L && all(raw[1:3] == as.raw(c(0xEF, 0xBB, 0xBF)))) raw <- raw[-(1:3)]
  txt <- rawToChar(raw)
  Encoding(txt) <- "UTF-8"
  con <- textConnection(txt, encoding = "UTF-8")
  on.exit(close(con))
  read.table(con, header = TRUE, sep = ";", dec = ",", quote = "\"",
             stringsAsFactors = FALSE, encoding = "UTF-8",
             colClasses = colClasses, check.names = FALSE, comment.char = "")
}
