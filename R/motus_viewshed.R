motus_viewshed <- function(coords = c(38.897659, -77.036564), ht = 0, zoom = 10,
                           carto_key = Sys.getenv("CARTO_API_KEY")) {
  if (!requireNamespace("elevatr", quietly = TRUE)) install.packages("elevatr", quiet = TRUE)
  if (!requireNamespace("raster", quietly = TRUE)) install.packages("raster", quiet = TRUE)
  if (!requireNamespace("mapview", quietly = TRUE)) install.packages("mapview", quiet = TRUE)
  if (!requireNamespace("sf", quietly = TRUE)) install.packages("sf", quiet = TRUE)
  if (!requireNamespace("tidygeocoder", quietly = TRUE)) install.packages("tidygeocoder", quiet = TRUE)
  
  # Set up mapview display options
  mt <- c("Esri.WorldGrayCanvas", "Esri.WorldImagery", "Esri.WorldTopoMap", "OpenStreetMap")
  mapview::mapviewOptions(basemaps = mt, basemaps.color.shuffle = FALSE,
                         na.color = "#FFFFFF00")
  carto_key <- trimws(carto_key)
  if (length(carto_key) != 1L || is.na(carto_key)) {
    stop("carto_key must be a single string.")
  }
  
  # Calculate range rings
  lon <- coords[2]; lat <- coords[1]
  # coords <- cbind(lon, lat)
  prj <- sprintf("+proj=laea +x_0=0 +y_0=0 +lon_0=%f +lat_0=%f", lon, lat)
  
  pt_ll <- sf::st_sfc(sf::st_point(rev(coords)), crs = 4326)
  pt <- sf::st_transform(pt_ll, prj)
  poly20 <-sf::st_sf(sf::st_set_crs(st_wedges(0, 0, 20000, 8), prj))
  poly15 <- sf::st_sf(sf::st_set_crs(st_wedges(0, 0, 15000, 8), prj))
  poly10 <- sf::st_sf(sf::st_set_crs(st_wedges(0, 0, 10000, 8), prj))
  poly5 <- sf::st_sf(sf::st_set_crs(st_wedges(0, 0, 5000, 8), prj))

  # Get DEM
  suppressMessages(
      elev <- elevatr::get_elev_raster(poly20, z = zoom, verbose = FALSE, clip = "locations") # not working at the moment
  )

  # Calculate viewshed
  pt_elev <- raster::extract(elev, sf::as_Spatial(pt)) + ht
  
  if (all(pt_elev > max(raster::values(elev), na.rm = TRUE))) {
    message("No elevation deficits found in viewshed. Displaying only 5, 10, and 15 km range rings.")
    suppressWarnings(
      m <- mapview::mapview(pt, layer.name = "Proposed station", 
                            alpha.regions = 0, cex = 4, color = "orange",
                            legend = FALSE, label = NULL) +
        mapview::mapview(poly15, layer.name = "15 km range", 
                         alpha.regions = 0, color = "white",
                         lwd = 1.25, legend = FALSE, label = NULL) +
        mapview::mapview(poly10, layer.name = "10 km range", 
                         alpha.regions = 0, color = "white",
                         lwd = 1.25, legend = FALSE, label = NULL) +
        mapview::mapview(poly5, layer.name = "5 km range", 
                         alpha.regions = 0, color = "white",
                         lwd = 1.25, legend = FALSE, label = NULL))
  } else {
    out <- elev - pt_elev
    out[out < 0] <- NA
    suppressWarnings(
      m <- mapview::mapview(out, layer.name = "Elev. deficit (m)",
                            col.regions = grDevices::hcl.colors(12, palette = "viridis")) +
        mapview::mapview(pt, layer.name = "Proposed station", 
                         alpha.regions = 0, cex = 4, color = "orange",
                         lwd = 1.25, legend = FALSE, label = NULL) +
        mapview::mapview(poly20, layer.name = "20 km range", 
                         alpha.regions = 0, color = "white",
                         lwd = 1.25, legend = FALSE, label = NULL) +
        mapview::mapview(poly15, layer.name = "15 km range", 
                         alpha.regions = 0, color = "white",
                         lwd = 1.25, legend = FALSE, label = NULL) +
        mapview::mapview(poly10, layer.name = "10 km range", 
                         alpha.regions = 0, color = "white",
                         lwd = 1.25, legend = FALSE, label = NULL) +
        mapview::mapview(poly5, layer.name = "5 km range", 
                         alpha.regions = 0, color = "white",
                         lwd = 1.25, legend = FALSE, label = NULL))
  }

  if (nzchar(carto_key)) {
    # Rebuild only basemaps and control; preserve viewshed overlays.
    m@map <- leaflet::clearTiles(m@map)
    m@map <- leaflet::removeLayersControl(m@map)
    m@map <- leaflet::addTiles(
      m@map,
      urlTemplate = paste0(
        "https://basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}.png?key=",
        utils::URLencode(carto_key, reserved = TRUE)
      ),
      group = "CartoDB.DarkMatter",
      attribution = paste0(
        '&copy; <a href="https://carto.com/">CARTO</a> ',
        '&copy; <a href="https://www.openstreetmap.org/copyright">',
        'OpenStreetMap</a> contributors'
      ),
      options = leaflet::tileOptions(maxZoom = 20)
    )
    for (provider in mt) {
      m@map <- leaflet::addProviderTiles(m@map, provider, group = provider)
      m@map <- leaflet::hideGroup(m@map, provider)
    }
    overlays <- c("Proposed station", "15 km range", "10 km range", "5 km range")
    if (!all(pt_elev > max(raster::values(elev), na.rm = TRUE))) {
      overlays <- c("Elev. deficit (m)", "20 km range", overlays)
    }
    m@map <- leaflet::addLayersControl(
      m@map, baseGroups = c("CartoDB.DarkMatter", mt), overlayGroups = overlays,
      options = leaflet::layersControlOptions(collapsed = TRUE)
    )
  } else {
    message("CARTO_API_KEY is not set; using Esri.WorldGrayCanvas.")
  }

  # m <- leaflet::setView(m@map, lon, lat, zoom = 11)
  return(m)
}

st_wedge <- function(x,y,r,start,width,n=150){
  theta = seq(start, start+width, length=n)
  xarc = x + r*sin(theta)
  yarc = y + r*cos(theta)
  xc = c(x, xarc, x)
  yc = c(y, yarc, y)
  sf::st_polygon(list(cbind(xc,yc)))   
}

st_wedges <- function(x, y, r, nsegs){
  width = (2*pi)/nsegs
  starts = seq(-0.5, by = 1, length.out = nsegs + 1)*width
  polys = lapply(starts, function(s){st_wedge(x,y,r,s,width)})
  mpoly = sf::st_cast(do.call(sf::st_sfc, polys), "MULTIPOLYGON")
  mpoly
}

# Abbreviated version
mv <- function(lat, lon, h = 1, z = 10) {
  motus_viewshed(c(lat, lon), ht = h, zoom = z)
}
