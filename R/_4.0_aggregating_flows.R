library(tidyverse)
library(sf)
library(dodgr)
library(geodist)


# read in MSOA centroids
lon_lat <- st_read(paste0("../data/",chosen_city,'/msoa_lon_lat.shp')) 
# flow data: there are 3 files (check script 3 and choose 1)
od_flow <- read_csv(paste0("../data/",chosen_city,'/flows_for_aggregated_routing_opt_3.csv')) 

# remove flows where ORIGIN = DESTINATION
od_flow <- od_flow %>% filter(`Area of residence` != `Area of workplace`)

# tranform into distance matrix for routing. 
# column_to_rownames added so that 1st column is not the MSOA names. It assigns the MSOA names to the row ID
od_flow_matrix <- 
  od_flow %>% 
  pivot_wider(names_from = `Area of workplace`, values_from = potential_demand) %>%
  tibble::column_to_rownames(var = "Area of residence") %>%  
  replace(is.na(.), 0) %>% as.matrix()    
# last line gives 0 values to intra flows, as NAs would cause problems
# This doesn't matter in calculations as intra flows aren't aggregated on road segments


# 'from' is the 1st Column - get the MSOA names using rownames and join them with the coordinates in lon_lat
from <- rownames(od_flow_matrix) %>% as.data.frame() %>% left_join(lon_lat, by = c("." = "msoa11cd")) %>%
  dplyr::select(lon, lat) %>% as.matrix()

# same as above but 'to is the column names(i.e. index row)
to <- colnames(od_flow_matrix) %>% as.data.frame() %>% left_join(lon_lat, by = c("." = "msoa11cd")) %>%
  dplyr::select(lon, lat) %>% as.matrix()

# # subsets for testing (THIS WORKS)
# from2 <- rownames(od_flow_matrix) %>% as.data.frame() %>% left_join(lon_lat, by = c("." = "MSOA11CD")) %>%
#   dplyr::select(lon, lat) %>% slice(1:10) %>% as.matrix()
# to2 <- colnames(od_flow_matrix) %>% as.data.frame() %>% left_join(lon_lat, by = c("." = "MSOA11CD")) %>%
#   dplyr::select(lon, lat) %>% slice(1:10) %>% as.matrix()
#   # select first 10 rows then 1st 10 columns
# od_flow_matrix_2 <- od_flow_matrix %>% as.data.frame() %>% slice(1:10) %>% select(1:10) %>% as.matrix()

# ROUTE
# load in graph saved in script 2
#graph <- readRDS(paste0("../data/",chosen_city,"/city_graph.Rds"))
streetnet_sc <- readRDS(paste0("../data/",chosen_city,"/unweighted_streetnet.Rds"))
######

# CREATE GRAPHS WITH DIFFERENT WEIGHTING PROFILES. THE WEIGHTING PROFILES ARE EDITED BY
# DOWNLOADING THE JSON IN -x-dodgr_weight_profiles.R AND EDITING IN A TEXT EDITOR


# this graph has weights so that low stress roads (secondary, tertiary) are preferred
graph_weighted <- weight_streetnet(streetnet_sc, 
                                  wt_profile_file = "../data/weight_profile_weighted.json")
# all road types are weighted equally here. We use these weights to get the absolute shortest paths
graph_unweighted <- weight_streetnet(streetnet_sc, 
                                     wt_profile_file = "../data/weight_profile_unweighted.json")


# # add flows to road segments # norm_sums isn't a parameter apparently. Tried updating dodgr...
# graph_flows <- dodgr_flows_aggregate(
#                   graph = graph_weighted,
#                   from = from, to = to, flows = od_flow_matrix,
#                   norm_sums = TRUE,
#                   contract = TRUE, 
#                   quiet = FALSE)
# 
# graph_flows2 <- dodgr_flows_aggregate(
#   graph = graph_weighted,
#   from = from, 
#   to = to, 
#   flows = od_flow_matrix,
#   norm_sums = FALSE)
#   contract = TRUE, quiet = FALSE)



# 
# # Turn into undirected graph 
# graph_undir <- dodgr::merge_directed_flows(graph_flows)
# 
# # convert to sf for prioritixing segments. 
# # Notice that the segments are merged (much less than graph_flows)
# graph_sf_default <- graph_undir %>% dodgr_to_sf()

# function to merge flows, turn into undirected graph, then to sf
aggregate_flows <- function(graph, from, to, flows){
  # add flows to road segments
  graph_flows <- dodgr::dodgr_flows_aggregate(
        graph = graph,
        from = from, 
        to = to, 
        flows = flows,
        contract = TRUE, 
        quiet = FALSE)
  # turn into undirected graph
  graph_undir <- dodgr::merge_directed_graph(graph_flows)
  # convert to sf
  graph_sf <-  dodgr::dodgr_to_sf(graph_undir)
  return(graph_sf)
  }

# Use function to aggregate flows on graphs

# weighted graph
graph_sf_weighted <- aggregate_flows(graph=graph_weighted, from=from, to=to, flows=od_flow_matrix)
# unweighted graph
graph_sf_unweight <- aggregate_flows(graph=graph_unweighted, from=from, to=to, flows=od_flow_matrix)

# save as RDS to load in next script (geojson, shp etc cause problems)
saveRDS(graph_sf_weighted, file = paste0("../data/", chosen_city, "/graph_with_flows_weighted.Rds"))
saveRDS(graph_sf_unweight, file = paste0("../data/", chosen_city, "/graph_with_flows_unweighted.Rds"))




rm(from, graph_default, graph_sf_default, graph_sf_trunk, graph_sf_unweight, graph_sf_weighted,
   graph_trunk, graph_unweighted, graph_weighted, lon_lat, od_flow, od_flow_matrix, streetnet_sc,
   to, aggregate_flows)
   








