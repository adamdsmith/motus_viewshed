motus_viewshed <- function(coords = c(38.897659, -77.036564), ht = 0, zoom = 10) {
  if (!requireNamespace("elevatr", quietly = TRUE)) install.packages("elevatr", quiet = TRUE)
  if (!requireNamespace("sp", quietly = TRUE)) install.packages("sp", quiet = TRUE)
  if (!requireNamespace("rgeos", quietly = TRUE)) install.packages("rgeos", quiet = TRUE)
  if (!requireNamespace("raster", quietly = TRUE)) install.packages("raster", quiet = TRUE)
  if (!requireNamespace("mapview", quietly = TRUE)) install.packages("mapview", quiet = TRUE)

  # Set up mapview display options
  mt <- c("CartoDB.DarkMatter", "Esri.WorldImagery", "Esri.WorldTopoMap")
  mapview::mapviewOptions(basemaps = mt, na.color = "#FFFFFF00")
  
  # Calculate range rings
  lon <- coords[2]; lat <- coords[1]
  coords <- cbind(lon, lat)
  prj <- sprintf("+proj=laea +x_0=0 +y_0=0 +lon_0=%f +lat_0=%f", lon, lat)
  
  pt_ll <- sp::SpatialPoints(coords, sp::CRS("+init=epsg:4326"))
  pt <- sp::spTransform(pt_ll, sp::CRS(prj))
  poly15 <- rgeos::gBuffer(pt, width = 15000, quadsegs = 12)
  poly10 <- rgeos::gBuffer(pt, width = 10000, quadsegs = 12)
  poly5 <- rgeos::gBuffer(pt, width = 5000, quadsegs = 12)

  # Get DEM
  suppressWarnings(
    suppressMessages(
      elev <- elevatr::get_elev_raster(poly15, z = zoom, clip = "locations", verbose = FALSE)
    )
  )

  # Calculate viewshed
  pt_elev <- raster::extract(elev, pt) + ht
  
  if (all(pt_elev > max(raster::values(elev), na.rm = TRUE))) {
    message("No elevation deficits found in viewshed. Displaying only 5, 10, and 15 km range rings.")
    suppressWarnings(
      m <- mapview::mapview(pt, layer.name = "Proposed station", 
                            alpha.regions = 0, cex = 4, color = "orange",
                            legend = FALSE, label = NULL) +
        mapview::mapview(poly15, layer.name = "15 km range", 
                         alpha.regions = 0, color = "white",
                         legend = FALSE, label = NULL) +
        mapview::mapview(poly10, layer.name = "10 km range", 
                         alpha.regions = 0, color = "white",
                         legend = FALSE, label = NULL) +
        mapview::mapview(poly5, layer.name = "5 km range", 
                         alpha.regions = 0, color = "white",
                         legend = FALSE, label = NULL))
  } else {
    out <- elev - pt_elev
    out[out < 0] <- NA
    suppressWarnings(
      m <- mapview::mapview(out, layer.name = "Elev. deficit (m)") +
        mapview::mapview(pt, layer.name = "Proposed station", 
                         alpha.regions = 0, cex = 4, color = "orange",
                         legend = FALSE, label = NULL) +
        mapview::mapview(poly15, layer.name = "15 km range", 
                         alpha.regions = 0, color = "white",
                         legend = FALSE, label = NULL) +
        mapview::mapview(poly10, layer.name = "10 km range", 
                         alpha.regions = 0, color = "white",
                         legend = FALSE, label = NULL) +
        mapview::mapview(poly5, layer.name = "5 km range", 
                         alpha.regions = 0, color = "white",
                         legend = FALSE, label = NULL))
  }

  m <- leaflet::setView(m@map, sp::coordinates(pt_ll)[1], 
                        sp::coordinates(pt_ll)[2],
                        zoom = 11)
  return(m)
}