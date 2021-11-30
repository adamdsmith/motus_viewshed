motus_viewshed <- function(lat, lon, ht = 0, max_range = 15) {
  options(repos = c(
    hypertidy = 'https://hypertidy.r-universe.dev',
    CRAN = 'https://cloud.r-project.org'))
  
  # Install some packages
  if (!requireNamespace("vapour", quietly = TRUE)) install.packages("vapour", quiet = TRUE)
  if (!requireNamespace("gdalio", quietly = TRUE)) install.packages("gdalio", quiet = TRUE)
  if (!requireNamespace("mapview", quietly = TRUE)) install.packages("mapview", quiet = TRUE)
  if (!requireNamespace("sf", quietly = TRUE)) install.packages("sf", quiet = TRUE)
  if (!requireNamespace("raster", quietly = TRUE)) install.packages("raster", quiet = TRUE)
  
  # Set up mapview display options
  mt <- c("CartoDB.DarkMatter", "Esri.WorldImagery", "Esri.WorldTopoMap", "OpenStreetMap")
  mapview::mapviewOptions(basemaps = mt, na.color = "#FFFFFF00", fgb = FALSE)
  
  # Function to create raster from DEM data
  gdalio_raster <- function(dsn, ...) {
      v <- gdalio::gdalio_data(dsn, ...)
      g <- gdalio::gdalio_get_default_grid()
      r <- raster::raster(raster::extent(g$extent), 
                          nrows = g$dimension[2], ncols = g$dimension[1], 
                          crs = g$projection)
      if (length(v) > 1) {
        r <- raster::brick(replicate(length(v), r, simplify = FALSE))
      }
      raster::setValues(r, do.call(cbind, v))
  }
  
  # Calculate range rings
  coords <- c(lon, lat)
  prj <- sprintf("+proj=laea +x_0=0 +y_0=0 +lon_0=%f +lat_0=%f", lon, lat)
  
  pt_ll <- sf::st_sfc(sf::st_point(coords), crs = 4326)
  pt <- sf::st_transform(pt_ll, prj)
  buff_dists <- seq(5, max(5, ceiling(max_range / 5) * 5), by = 5)

  # Get DEM
  # src <- "/vsicurl/https://opentopography.s3.sdsc.edu/raster/NASADEM/NASADEM_be.vrt"
  src <- "/vsicurl/https://opentopography.s3.sdsc.edu/raster/AW3D30/AW3D30_global.vrt"
  gdalio::gdalio_set_default_grid(
    list(
      extent = c(-1, 1, -1, 1) * max(buff_dists) * 1000, 
      dimension = c(707, 707), 
      projection = prj
    )
  )
  m <- gdalio::gdalio_matrix(src)

  # Calculate viewshed
  pt_elev <- m[354, 354] + ht
  
  if (pt_elev > max(m)) {
    message("No elevation deficits found in viewshed.")
    m <- mapview::mapview(pt, layer.name = "Proposed station", 
                          alpha.regions = 0, cex = 4, color = "orange",
                          legend = FALSE, label = NULL)
  } else {
    # Create raster only if necessary
    elev <- gdalio_raster(src)
    out <- elev - pt_elev
    out[out < 0] <- NA
    m <- mapview::mapview(out, layer.name = "Elev. deficit (m)") +
      mapview::mapview(pt, layer.name = "Proposed station", 
                       alpha.regions = 0, cex = 4, color = "orange",
                       legend = FALSE, label = NULL)
  }
  
  # Add range rings
  for (buff in buff_dists) {
    b <- sf::st_buffer(pt, dist = buff * 1000, nQuadSegs = 12)
    m <- m +
      mapview::mapview(b, layer.name = paste(buff, "km range"), 
                       alpha.regions = 0, color = "white",
                       legend = FALSE, label = NULL)
  }

  return(m)
}