library(tidyverse)
library(dodgr)
library(sf)
library(osmdata)
library(lwgeom)
library(pct)
library(slopes)

###############
# IMPORTING SPATIAL DATA FOR ROUTING
###############
# function to filter MSOAs that are within a certain city. 
msoas_in_city <- function(df, city_name) {
  x <- df %>% filter(city == city_name)
  return(x)
}
# get MSOAs in chosen_city. chosen_city is chosen in script 1
msoas_city <- msoas_in_city(city_names, chosen_city)
#save it for plotting later
write_csv(msoas_city, path = paste0("data/",chosen_city,"/msoa_codes_city.csv"))


# get geometry of msoas_city. We need this geometry for plotting later
# download as geojson from this api link: https://opendata.arcgis.com/datasets/826dc85fb600440889480f4d9dbb1a24_0.geojson
# 650mb!! I just download as shp (only 250mb but no api), save in directory, and load in 
city_geom <- sf::st_read("data-raw/MSOA_2011_Boundaries/Middle_Layer_Super_Output_Areas__December_2011__Boundaries.shp") %>%
  st_transform(4326)
# filter only MSOAs in the msoas_city df
city_geom <- city_geom %>% dplyr::filter(msoa11cd %in% msoas_city$MSOA11CD)
# save to load in when plotting
st_write(city_geom, paste0("data/",chosen_city,"/msoas_geometry.shp"), append=FALSE)


# get population weighted centroids from pct and change crs (default is northing)
msoa_centroids <- pct::get_centroids_ew() %>% st_transform(4326)
# keep only centroids of chosen city 
msoa_centroids <- msoa_centroids %>% dplyr::filter(msoa11cd %in% msoas_city$MSOA11CD)

#######################
# SNAPPING CENTROIDS TO MAIN OSM ROADS. Do this to prevent centroids snapping to innaccessible road segments

#1. Get stree network and filter main road types (filter argument can be changed)
# get boundary to query OSM roads from
pts <- st_coordinates (msoa_centroids$geometry)
#query OSM through 
roads <- dodgr_streetnet(pts = pts, expand = 0.05) %>% 
  filter(highway %in% c('primary', 'secondary', 'tertiary'))

#plot(st_geometry(roads))

#2. snap centroids to lines

# function from https://stackoverflow.com/questions/51292952/snap-a-point-to-the-closest-point-on-a-line-segment-using-sf
st_snap_points = function(x, y, max_dist = 1000) {
  
  if (inherits(x, "sf")) n = nrow(x)
  if (inherits(x, "sfc")) n = length(x)
  
  out = do.call(c,
                lapply(seq(n), function(i) {
                  nrst = st_nearest_points(st_geometry(x)[i], y)
                  nrst_len = st_length(nrst)
                  nrst_mn = which.min(nrst_len)
                  if (as.vector(nrst_len[nrst_mn]) > max_dist) return(st_geometry(x)[i])
                  return(st_cast(nrst[nrst_mn], "POINT")[2])
                })
  )
  return(out)
}

msoa_centroids_snapped <- 
  st_snap_points(msoa_centroids, roads, max_dist = 1000) %>%   # if dist to nearest road > max dist, point is unchanged
  st_as_sf() %>%   # convert to get it in a dataframe
  bind_cols(msoa_centroids) %>%  # bind with msoa centroids df to ge MSOA IDs
  dplyr::select(-c(geometry)) %>% # drop old geometry
  dplyr::rename(centroid = x)

# check how the points were shifted
plot(st_geometry(roads))
plot(st_geometry(msoa_centroids), add = TRUE, col = 'red')
plot(st_geometry(msoa_centroids_snapped), add = TRUE, col = 'green')

# check that bind_cols() was correct. Plot individual points:
plot(st_geometry(roads))
plot(st_geometry(msoa_centroids$geometry[10]), add = TRUE, col = 'red')
plot(st_geometry(msoa_centroids_snapped$centroid[10]), add = TRUE, col = 'green')

#clear environment
rm(roads)
########################

# save this version for routing in `4_aggregating_flows`
msoa_centroids_snapped %>% 
  cbind(st_coordinates(.)) %>%  #split geometry into X and Y columns
  rename(lon = X, lat = Y) %>%  # rename x and y
  dplyr::select(-c(msoa11nm)) %>% 
  #st_write("data/alt_city/msoa_lon_lat.shp", append=FALSE) # save as shp file. append=FALSE to overwrite existing layer
  st_write(paste0("data/",chosen_city,"/msoa_lon_lat.shp"), append=FALSE)

# read it in for dodgr_dist calculations (below)
msoa_lon_lat <- st_read(paste0("data/",chosen_city,"/msoa_lon_lat.shp")) %>%
  dplyr::select(c(lon, lat))  %>%
  st_drop_geometry()

############
# DISTANCE MATRIX USING DODGR
############

# this downloads all the road data from OSM (equivalent to : key = 'highway')
pts <- st_coordinates (msoa_centroids_snapped)
#silicate format: penalizes intersections and hilliness
streetnet_sc <- dodgr_streetnet_sc(pts = pts, expand = 0.05)

# add elevation data to sc object 

# Option 1: Download from https://earthexplorer.usgs.gov/

# #London is split between two tiles. we load both and then merge them
# uk_1 <- raster::raster('data-raw/UK_Elevation/srtm_36_02.tif')
# uk_2 <- raster::raster('data-raw/UK_Elevation/srtm_37_02.tif')
# #merge
# uk_elev <- raster::merge(uk_1, uk_2)
# # write to disk for osm_elevation function (need to pass file path...)
# writeRaster(uk_elev, 'data/uk_elev.tif')
# # we only need the merged one
# rm(uk_1, uk_2, uk_elev)

# Option 2: Download for specific city using elevatr package:

# specify the crs
prj_elev <- "+init=EPSG:4326"
# download elevation for study area using elevatr
city_elev <- elevatr::get_elev_raster(city_geom, z= 9, prj = prj_elev, expand = 0.05)
# save
raster::writeRaster(city_elev, paste0("data/", chosen_city, '/city_elev.tif'))

# add the elevation data to the vertices
#streetnet_sc <- osmdata::osm_elevation(streetnet_sc, elev_file = c('data/uk_elev.tif'))
streetnet_sc <- osmdata::osm_elevation(streetnet_sc, elev_file = paste0("data/", chosen_city, '/city_elev.tif'))

# SAVE STREETNET FOR SCRIPT 4. There we will be trying out different weighting profiles
saveRDS(streetnet_sc, file = paste0("data/",chosen_city,"/unweighted_streetnet.Rds"))
# make graph for routing
graph <- weight_streetnet(streetnet_sc, wt_profile = "bicycle")

# contract graph for faster routing
graph_contracted <- dodgr_contract_graph(graph)
# get distance matrix
dist_mat <- dodgr_dists(graph_contracted, from = msoa_lon_lat, to = msoa_lon_lat) %>% as.data.frame()

# Change column names for pivoting
colnames(dist_mat) <- msoa_centroids$msoa11cd
# column bind to add MSOA IDs to df. If this is done using rownames then then it is added as a column index (cannot pivot)
dist_mat <- cbind(msoa_centroids$msoa11cd, dist_mat) %>% rename(from = `msoa_centroids$msoa11cd`)

# Change to long format to merge with flows
dist_mat <- dist_mat %>%
  pivot_longer(-from, names_to = "to", values_to = "dist")

# save to use in calculation of potential demand (next script)
flows_city <- readr::read_csv(paste0("data/",chosen_city,"/flows_city.csv"))

# flows_london %>% subset(select = -c(city_origin, city_dest)) %>%
#   left_join(dist_mat, by = c("Area of residence" = "from" , "Area of workplace" = "to")) %>%
#   write_csv(path = "data/flows_dist_for_potential_flow.csv")

flows_slope <- flows_city %>% subset(select = -c(city_origin, city_dest)) %>%
  left_join(dist_mat, by = c("Area of residence" = "from" , "Area of workplace" = "to"))


##### ADD SLOPE - START
# add centroids for routing
flows_slope <- flows_slope %>% left_join(msoa_centroids_snapped[,c('msoa11cd' ,'centroid')],
                                    by = c("Area of residence" = "msoa11cd")) %>%
                               rename(cent_orig = centroid)

flows_slope <- flows_slope %>% left_join(msoa_centroids_snapped[,c('msoa11cd' ,'centroid')],
                                     by = c("Area of workplace" = "msoa11cd")) %>%
                               rename(cent_dest = centroid)

# coordinates for bb
#pts <- st_coordinates(msoa_centroids_snapped)
# road network for routing (cannot use streetnet_sc from above as stplanr function only takes sf)
net <- dodgr::dodgr_streetnet(pts = pts, expand = 0.1)

# load in elevation data
#elev <- raster::raster('data/uk_elev.tif')

# 1. get geometries
route <- function(df, net){
  nrows <- nrow(df)
  i = 1:nrows
  # # empty geometry column and assign it's crs
  df$route = st_sfc(lapply(1:nrows, function(x) st_geometrycollection())) 
  st_crs(df$route) <- 4326
  # get shortest route for each OD pair
  df$route[i] <- st_geometry(stplanr::route_dodgr(from = df$cent_orig[i], to = df$cent_dest[i], net = net))
  return(df)
}

# 2. get slopes
slope <- function(df, elev){
  nrows <- nrow(df)
  i = 1:nrows
  # get slope of the shortest route between each OD pair. Route obtained from function above
  df$slope[i] <- slopes::slope_raster(df$route[i], elev)
  return(df)
}

# get routes column then slope column (function 1 then function 2)
#flows_slope <- flows_slope %>% route(net = net) %>% slope(elev = uk_elev)
flows_slope <- flows_slope %>% route(net = net) %>% slope(elev = city_elev)

flows_slope %>% 
  dplyr::select(-c(cent_orig, cent_dest, route)) %>%
  write_csv(path = paste0("data/",chosen_city,"/flows_dist_elev_for_potential_flow.csv"))

##### ADD SLOPE - END


##### COMPARE WEIGHTING PROFILES - START

### Here I look at the distance between OD pairs using 3 different weighting profiles
# 1) Unweighted. All roads are the same
# 2) Weighted. Priority in descending order: cycleways -> Residential/Tertiary -> Secondary -> Primary -> Trunk
# 3) All roads are equal but Motorways, Trunk, and Primary roads are banned

                        ###### (1) ######

# # make graph for routing
graph_1 <- weight_streetnet(streetnet_sc, wt_profile_file = "data/weight_profile_unweighted.json")
# 
# # contract graph for faster routing
graph_contracted <- dodgr_contract_graph(graph_1)
# # get distance matrix
dist_mat_1 <- dodgr_dists(graph_contracted, from = msoa_lon_lat, to = msoa_lon_lat) %>% as.data.frame()
# # Change column names for pivoting
colnames(dist_mat_1) <- msoa_centroids$msoa11cd
# # column bind to add MSOA IDs to df. If this is done using rownames then then it is added as a column index (cannot pivot)
dist_mat_1 <- cbind(msoa_centroids$msoa11cd, dist_mat_1) %>% rename(from = `msoa_centroids$msoa11cd`)
# # Change to long format to merge with flows
dist_mat_1 <- dist_mat_1 %>%
   pivot_longer(-from, names_to = "to", values_to = "dist") %>% 
   rename(`dist_1`  = dist)

                               ###### (2) ######

graph_2 <- weight_streetnet(streetnet_sc, wt_profile_file = "data/weight_profile_weighted.json")

graph_contracted <- dodgr_contract_graph(graph_2)

dist_mat_2 <- dodgr_dists(graph_contracted, from = msoa_lon_lat, to = msoa_lon_lat) %>% as.data.frame()

colnames(dist_mat_2) <- msoa_centroids$msoa11cd

dist_mat_2 <- cbind(msoa_centroids$msoa11cd, dist_mat_2) %>% 
  rename(from = `msoa_centroids$msoa11cd`) %>%
  pivot_longer(-from, names_to = "to", values_to = "dist") %>% 
  rename(`dist_2`  = dist)

                              ###### (3) ######

graph_3 <- weight_streetnet(streetnet_sc, wt_profile_file = "data/weight_profile_no_primary_trunk.json")

graph_contracted <- dodgr_contract_graph(graph_3)

dist_mat_3 <- dodgr_dists(graph_contracted, from = msoa_lon_lat, to = msoa_lon_lat) %>% as.data.frame()

colnames(dist_mat_3) <- msoa_centroids$msoa11cd

dist_mat_3 <- cbind(msoa_centroids$msoa11cd, dist_mat_3) %>% 
  rename(from = `msoa_centroids$msoa11cd`) %>%
  pivot_longer(-from, names_to = "to", values_to = "dist") %>% 
  rename(`dist_3`  = dist)

##### merge all to one dataframe 
dist_mat_all <- dist_mat_1 %>% left_join(dist_mat_2, by = c("from" = "from", "to" = "to")) %>% 
  left_join(dist_mat_3, by = c("from" = "from", "to" = "to"))

##### CIRCUITRY
# weighted / unweighted
dist_mat_all$circuity_1_2 <- dist_mat_all$dist_2 / dist_mat_all$dist_1
# weighted_no_main_roads / unweighted
dist_mat_all$circuity_1_3 <- dist_mat_all$dist_3 / dist_mat_all$dist_1
# weighted_no_main_roads / weighted
dist_mat_all$circuity_2_3 <- dist_mat_all$dist_3 / dist_mat_all$dist_2

# histogram
dist_mat_all %>% filter(circuity_1_3 >= 1) %>%
ggplot(aes(x = circuity_1_3)) + 
  geom_histogram(color = "black", alpha = 0.5) 

 # COMPARE ONLY 1_2 with 1_3 to make the point 
# boxplot
dist_mat_all_box <- dist_mat_all %>%
  select(circuity_1_2, circuity_1_3) %>%
  filter(circuity_1_2 >= 1 & circuity_1_3 >= 1) %>%
  pivot_longer(everything(), names_to = "circuity", values_to = "value")  # everything() so that you pivot all columns

dist_mat_all_box %>% 
  filter(value <= 3) %>%   # because there are a few very large values that ruin the scale of the plot
ggplot(aes(value, circuity)) + 
  geom_boxplot(outlier.alpha = 0.5) +
  scale_x_continuous(name = 'Distance Relative to Unweighted \nShortest Path (Ratio)', 
                     breaks = seq(1, 3, by = 0.2)) +  # seq(1, max(dist_mat_all_box$value, , by = 0.2)
  scale_y_discrete(name = '', labels=c("Weighted", "Weighted \n(No Trunk \n or Primary)")) +
  #xlim(NA, 3) +
  #ggtitle("Comparing Weighted to Unweighted Shortest Paths") +
  theme_minimal(base_size = 13)

ggsave(paste0("data/", chosen_city,"/Plots/boxplot_weighted_unweighted_distances.png"))

# point graph distance vs circuity
dist_mat_all %>% filter(circuity_1_2 >= 1) %>%
  ggplot(aes(x = dist_1, y = circuity_1_2)) + 
  geom_point(color = "darkred", alpha = 0.3) +
  geom_smooth(color = "black", alpha = 0.5) 


##### COMPARE WEIGHTING PROFILES - END


##########
# GETTING SF STRAIGHT LINE DISTANCES TO COMPARE WITH RESULTS
##########

# flows_london <- read_csv("data/flows_london.csv") %>% 
#       subset(select = -c(city_origin, city_dest))
# 
# # add geometry of origin
# flows_london <- flows_london %>% left_join(spatial_london[ , c("MSOA11CD", "geometry", "centroid")], 
#                                            by = c("Area of residence" = "MSOA11CD")) %>%
#   rename(geom_orig = geometry, cent_orig = centroid)
# # add geometry of destination
# flows_london <- flows_london %>% left_join(spatial_london[ , c("MSOA11CD", "geometry", "centroid")], 
#                                            by = c("Area of workplace" = "MSOA11CD")) %>%
#   rename(geom_dest = geometry, cent_dest = centroid)
# 
# # get straight line distances - this takes TIMMEEEE
# flows_london <- flows_london %>% 
#   mutate(dist =st_distance(cent_orig, cent_dest, by_element = T))
# 
# 
# # Create dataframe with both straight line distances and dodgr distance
# distances <- flows_london %>% 
#   subset(select = -c(geom_orig, geom_dest, cent_orig, cent_dest)) %>% 
#   subset(select = c(`Area of residence`, `Area of workplace`, dist)) %>%
#   rename(dist_straight = dist) %>% 
#   left_join(dist_mat, by = c("Area of residence" = "from", "Area of workplace" = "to")) %>%
#   rename(dist_dodgr = dist)
# 
# # save for reference
# write_csv(distances, path = paste0("data/",chosen_city, dist_straight_vs_dodgr.csv"))

# remove variables from global environment
rm(city_geom, city_names, dist_mat, dist_mat_1, dist_mat_2, dist_mat_3, dist_mat_all, dist_mat_all_box, 
   flows_city, flows_slope, graph, graph_contracted, graph_1, graph_2, graph_3,
   msoa_centroids, msoa_centroids_snapped, msoa_lon_lat, msoas_city,
   net, pts, streetnet_sc, uk_elev, prj_elev, city_elev)

