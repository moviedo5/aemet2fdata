
# =====================================================================
#  Construcción de aemet2fdata 
#  Ejecutar desde la raíz del paquete
# =====================================================================
unlink(c("inst/doc", "doc"), recursive = TRUE)
library(devtools)
stopifnot(file.exists("DESCRIPTION"))            # estamos en la raíz

# 1. Documentación: NAMESPACE + man/
unlink(c("inst/doc", "doc"), recursive = TRUE)   # restos de build_vignettes()
document()
for (f in list.files("man", "\\.Rd$", full.names = TRUE)) tools::checkRd(f)

# 2. README.md desde README.Rmd 
build_readme()

# 3. Comprobar (construye el paquete y las viñetas por dentro) e instalar
check()                   # check(vignettes = FALSE) para ir más rápido
install()

# 4. Web
pkgdown::build_site()

# 5. Antes de enviar a CRAN
# check_win_devel()       # sustituye a build_win(), que ya no existe

