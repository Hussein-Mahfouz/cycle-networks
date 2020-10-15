##### IDENTIFY ALL ROAD SEGMENTS WITH DEDICATED CYCLING INFRASTRUCTURE #####
############################################################################

library(sf)
library(dodgr)
library(tidyverse)
library(tmap)

########
# Get road network through dodgr
########

# centroids for bounding box of chosen city
msoa_centroids <- st_read(paste0("../data/", chosen_city,"/msoa_lon_lat.shp"))

# bounding box
pts <- st_coordinates (msoa_centroids)
#this downloads all the road data from OSM (equivalent to : key = 'highway')
streetnet <- dodgr_streetnet(pts = pts, expand = 0.05)

# filter out useful columns
streetnet2 <- streetnet %>% 
  dplyr::select(osm_id, bicycle, cycleway, highway,
                lanes, maxspeed)
# add length column
streetnet2 <- streetnet2 %>% dplyr::mutate(length_m = st_length(.))

########
# Check which OSM tags are useful for identifying existence of bicycle infrastructure
########

# check different columns
bicycle <- streetnet2 %>% 
  st_drop_geometry() %>%
  group_by(bicycle) %>% 
  summarize(segments=n(), length_m = sum(length_m))

cycleway <- streetnet2 %>% 
  st_drop_geometry() %>%
  group_by(cycleway) %>% 
  summarize(segments=n(), length_m = sum(length_m))

highway <- streetnet2 %>% 
  st_drop_geometry() %>%
  group_by(highway) %>% 
  summarize(segments=n(), length_m = sum(length_m))

# MOST ARE NA
lanes <- streetnet2 %>% 
  st_drop_geometry() %>%
  group_by(lanes) %>% 
  summarize(segments=n(), length_m = sum(length_m))

# MOST ARE NA
maxspeed <- streetnet2 %>% 
  st_drop_geometry() %>%
  group_by(maxspeed) %>% 
  summarize(segments=n(), length_m = sum(length_m))

# MOST ARE NA
# segregated <- streetnet2 %>% 
#   st_drop_geometry() %>%
#   group_by(segregated) %>% 
#   summarize(segments=n(), length_m = sum(length_m))

########
# Identify all road segments with cycling infrastructure 
########

# Read in the graph with the road network and flows
graph_sf <- readRDS(paste0("../data/", chosen_city,"/graph_with_flows_weighted.RDS"))

# this is all road segments with bicycle == 'designated'
cycle_designated <- streetnet2 %>% 
  filter(bicycle == 'designated') %>%
  st_combine()  # combine them into one geometry for st_within argument

# Get all features of graph_sf that are within (completely overlap with) cycle_designated
sel_sgbp <- st_within(x=graph_sf, y=cycle_designated)
sel_logical <- lengths(sel_sgbp) > 0
# subset graph_sf to edges with cycle_designated
cycle_designated <- graph_sf[sel_logical, ]
# plot to show
plot(st_geometry(graph_sf), col='lightgrey')
plot(st_geometry(cycle_designated), add=TRUE)


# this is all road segments with highway == 'cycleway'
cycleways <- streetnet2 %>% 
  filter(highway == 'cycleway') %>% 
  st_combine()

# Get all features of graph_sf that are within (completely overlap with) cycleways
sel_sgbp <- st_within(x=graph_sf, y=cycleways)
sel_logical <- lengths(sel_sgbp) > 0
# subset graph_sf to edges with cycleways
cycleways <- graph_sf[sel_logical, ]
# plot to show
plot(st_geometry(graph_sf), col='lightgrey')
plot(st_geometry(cycleways), add=TRUE)

# tracks:   all road segments with cycleway == 'track'

cycle_tracks <- streetnet2 %>% 
  filter(cycleway == 'track') %>% 
  st_combine()

# Get all features of graph_sf that are within (completely overlap with) cycleways
sel_sgbp <- st_within(x=graph_sf, y=cycle_tracks)
sel_logical <- lengths(sel_sgbp) > 0
# subset graph_sf to edges with cycleways
cycle_tracks <- graph_sf[sel_logical, ]
# plot to show
plot(st_geometry(graph_sf), col='lightgrey')
plot(st_geometry(cycle_tracks), add=TRUE)


# Show that cycle_designated is not completely contained within cycleways. 
plot(st_geometry(graph_sf), col='lightgrey')
plot(st_geometry(cycle_designated), add=TRUE, col='darkred')
plot(st_geometry(cycleways), add=TRUE, col='green')

# TMAPS to show tag inconsistencies

# bicycle = designated
tm_shape(graph_sf) +
  tm_lines(col = 'gray90') +
  tm_shape(cycle_designated) +
  tm_lines(title.col = "Priority (km)",
           col = 'darkgreen',
           lwd = 1.5) +
  tm_layout(title = "OSM tag: \nbicycle = designated",        
            title.size = 1.2,
            title.color = "azure4",
            title.position = c("left", "top"),
            inner.margins = c(0.1, 0.1, 0.1, 0.1),    # bottom, left, top, and right margin
            fontfamily = 'Georgia',
            legend.position = c("right", "bottom"),
            frame = FALSE) -> p1

# highway = cycleway
tm_shape(graph_sf) +
  tm_lines(col = 'gray90') +
  tm_shape(cycleways) +
  tm_lines(title.col = "Priority (km)",
           col = 'darkgreen',
           lwd = 1.5) +
  tm_layout(title = "OSM tag: \nhighway = cycleway",        
            title.size = 1.2,
            title.color = "azure4",
            title.position = c("left", "top"),
            inner.margins = c(0.1, 0.1, 0.1, 0.1),    # bottom, left, top, and right margin
            fontfamily = 'Georgia',
            legend.position = c("right", "bottom"),
            frame = FALSE) -> p2

# cycleway = track
tm_shape(graph_sf) +
  tm_lines(col = 'gray90') +
  tm_shape(cycle_tracks) +
  tm_lines(title.col = "Priority (km)",
           col = 'darkgreen',
           lwd = 1.5) +
  tm_layout(title = "OSM tag: \ncycleway = track",        
            title.size = 1.2,
            title.color = "azure4",
            title.position = c("left", "top"),
            inner.margins = c(0.1, 0.1, 0.1, 0.1),    # bottom, left, top, and right margin
            fontfamily = 'Georgia',
            legend.position = c("right", "bottom"),
            frame = FALSE) -> p3

# bicycle = designated & highway != cycleway
tm_shape(graph_sf) +
  tm_lines(col = 'gray90') +
  tm_shape(cycle_designated) +
  tm_lines(title.col = "Priority (km)",
           col = 'firebrick2',
           lwd = 1.4) +
  tm_shape(cycleways) +
  tm_lines(title.col = "Priority (km)",
           col = 'gray90',
           lwd = 1.8) +
  tm_layout(title = "bicycle = designated & \nhighway != cycleway",        
            title.size = 1.2,
            title.color = "azure4",
            title.position = c("left", "top"),
            inner.margins = c(0.1, 0.1, 0.1, 0.1),    # bottom, left, top, and right margin
            fontfamily = 'Georgia',
            legend.position = c("right", "bottom"),
            frame = FALSE) +
  tm_scale_bar(color.dark = "gray60") ->  p4


p <- tmap_arrange(p1, p2, p4, nrow = 1)


tmap_save(tm = p, filename = paste0("../data/", chosen_city,"/Plots/OSM_identifying_cycle_infrastructure.png"),
          width=10, height=5)



# create a combined geometry with all edges matching either of the three conditions
# highway == 'cycleway' | bicycle == 'designated' | cycleway == 'track'. Since we know that none of them
# completely contains the other
graph_sf_cycle <- streetnet2 %>% 
  filter(highway == 'cycleway' | bicycle == 'designated' | cycleway == 'track') %>%
  st_combine()

# Get all features of graph_sf that have dedicated cycling infrastructure
sel_sgbp <- st_within(x=graph_sf, y=graph_sf_cycle)
sel_logical <- lengths(sel_sgbp) > 0
graph_sf_cycle <- graph_sf[sel_logical, ]
# plot
plot(st_geometry(graph_sf), col='lightgrey')
plot(st_geometry(graph_sf_cycle), add=TRUE, col='red')

# check length of cycling infrastructure 
sum(graph_sf$d)
sum(graph_sf_cycle$d)

# We need to add a column in graph_sf to identify all edges with cycle infrastructure
# add a cycle_infra column to graph_sf_cycle and give all edges a value of 1, then 
# join with graph_sf

graph_sf_cycle <-
  graph_sf_cycle %>% st_drop_geometry() %>%
  mutate(cycle_infra= 1) %>%
  dplyr::select(c(edge_id, cycle_infra))

# this will add the cycle_infra column to the original graph_sf
graph_sf <- dplyr::left_join(graph_sf, graph_sf_cycle, by = "edge_id")
# all NA values in cycle_infra are those that had nothing to join to. It means they have no 
# cycling infrastructure. We will give them a value of 0 for cycle_infra
graph_sf$cycle_infra[is.na(graph_sf$cycle_infra)] <- 0

# save it as an RDS
saveRDS(graph_sf, file = paste0("../data/", chosen_city, "/graph_with_flows_weighted.Rds"))

###### FUNCTION TO ADD BINARY COLUMN INDICATING THE PRESENCE OF CYCLING INFRASTRUCTURE #####

# Turn the above into a function so I can use it with aggregated-flow graphs outputed using different 
# weighting profiles

infra_exists <- function(graph, network){

  # create a combined geometry with all edges matching either of the two conditions
  graph_cycle <- network %>% 
  filter(highway == 'cycleway' | bicycle == 'designated' | cycleway == 'track') %>%
  st_combine()
  
  # Get all features of graph_sf that have dedicated cycling infrastructure
  sel_sgbp <- st_within(x=graph, y=graph_cycle)
  sel_logical <- lengths(sel_sgbp) > 0
  graph_cycle <- graph[sel_logical, ]
  
  # We need to add a column in graph_sf to identify all edges with cycle infrastructure
  # add a cycle_infra column to graph_sf_cycle and give all edges a value of 1, then 
  # join with graph
  graph_cycle <-
    graph_cycle %>% st_drop_geometry() %>%
    mutate(cycle_infra= 1) %>%
    dplyr::select(c(edge_id, cycle_infra))
  
  #join the cycle_infra column to the original graph
  graph <- dplyr::left_join(graph, graph_sf_cycle, by = "edge_id")
  
  # all NA values in cycle_infra are those that had nothing to join to. It means they have no 
  # cycling infrastructure. We will give them a value of 0 for cycle_infra
  graph$cycle_infra[is.na(graph$cycle_infra)] <- 0
  
  return(graph)
}

# Read in the other graphs, add column for cycling infrastrucure, then overwrite
graph_sf_unweight <- readRDS(paste0("../data/", chosen_city,"/graph_with_flows_unweighted.RDS"))
graph_sf_unweight <- infra_exists(graph=graph_sf_unweight, network=streetnet2)
saveRDS(graph_sf_unweight, file = paste0("../data/", chosen_city, "/graph_with_flows_unweighted.Rds"))


# graph_sf_trunk <- readRDS(paste0("../data/", chosen_city,"/graph_with_flows_trunk.RDS"))
# graph_sf_trunk <- infra_exists(graph_sf_trunk, streetnet2)
# saveRDS(graph_sf_trunk, file = paste0("../data/", chosen_city, "/graph_with_flows_trunk.Rds"))


#clean environment
rm(bicycle, cycle_designated, cycle_tracks, cycleway, cycleways, graph_sf, 
   graph_sf_cycle, graph_sf_trunk, graph_sf_unweight, 
   highway, lanes, maxspeed, msoa_centroids, pts, segregated,
   sel_sgbp, streetnet, streetnet2, sel_logical, p, p1, p2, p3, p4, infra_exists)


