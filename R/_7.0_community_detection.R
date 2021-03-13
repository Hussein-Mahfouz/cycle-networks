library(sf)
library(sfnetworks)
library(tidygraph)
library(tidyverse)
library(tmap)


################ 1. COMMUNITY DETECTION #################

# edges are the msoa od pairs. 
# nodes are the msoa centroids
# You don''t need the nodes for community detection. They are used to store the community detection results 

#tidygraph
nodes <- st_read(paste0("data/", chosen_city,"/msoa_lon_lat.shp"))
edges <- read_csv(paste0("data/", chosen_city,"/flows_for_desire_lines.csv"))
# change names of columns to from and to -> UNNECESSARY IF THEY ARE FIRST TWO COLUMNS
# edges <- edges %>% rename(from = `Area of residence`, to = `Area of workplace`) 


# convert edge dataframe to graph
graph <- as_tbl_graph(edges, directed = FALSE)
# choose an a community detection algorithm and assign MSOAs to groups (weight is the flow)
graph_louvain <- graph %>%  activate(nodes) %>%
      mutate(group = group_louvain(weights = `potential_demand`))
# extract nodes so that you can join group results onto the M
community_assignment <- graph_louvain %>% activate("nodes") %>% as_tibble()
# join group result to each MSOA
nodes <- nodes %>% dplyr::left_join(community_assignment, by =  c("msoa11cd" = "name"))

# count number of MSOAs in each group
nodes %>% st_drop_geometry() %>%
  group_by(group) %>% 
  summarize(count = n()) %>% arrange(desc(count))

# read in msoa border geometry 
msoa_borders <- st_read(paste0("data/", chosen_city,"/msoas_geometry.shp"))

plot(st_geometry(msoa_borders))
plot(nodes['group'], add = TRUE)


# read in road edges with aggregated flow data 
road_segments <- readRDS(paste0("data/", chosen_city,"/graph_with_flows_weighted.Rds"))
#road_segments <- road_segments %>% dplyr::select(flow)

# plot
plot(st_geometry(msoa_borders))
plot(st_geometry(road_segments), add = TRUE, col = "darkred")

############### 2. ASSIGNING COMMUNITIES TO EDGES ###############

# We need to assign a community to each edge. I am doing this in two steps:

# 1. Assign each edge to an MSOA
# 2. Assign each edge to the same community of its MSOA

########## 2.1: FUNCTION FOR ASSIGNING ROAD EDGES TO MSOAS ###########

# Below function does the following:
 # if road segment does not intersect with any msoa border, snap it to the nearesr msoa centroid
 # if road segment interect (crosses) more than one msoa border, calculate the length of intersection with
 # with all intersecting MSOAs and assign it to the one it intersect with most
 # if road segment falls completely within one msoa, assign it to that msoa

assign_edge_to_polygon = function(x, y, z) {
  # x = sf with linestring features (road edges)
  # y = sf with polygon features (msoa borders)
  # z = sf with point features (msoa centroids)
                   ##############
  #### this function requires a column in y and z named msoa11cd!!!! ####
                  ###############
  if (inherits(x, "sf")) n = nrow(x)
  if (inherits(x, "sfc")) n = length(x)
  
  out = do.call(c,
                lapply(seq(n), function(i) {
                  # nrst is a list! It returns the msoa row number/s
                  nrst = st_intersects(st_geometry(x)[i], y)
                  # if intersect returns nothing, this edge is outside of all MSOA geometries
                  # get nearest msoa centroid to edge and assign it to it
                  if ( length (nrst[[1]]) == 0 ){
                    nrst = st_nearest_feature(st_geometry(x)[i], z)
                    msoa_code = as.character(z$msoa11cd[nrst[[1]]])
                  }
                  # if edge intersect with more than 1 msoa (does not fall completely inside 1), then
                  # find the length of intersection with each, and assign it to the one it intersects with more
                  else if ( length (nrst[[1]]) > 1 ){
                    # gets the msoa list position of the biggest intersection (intersection length with the different msoas is compared first)
                    a = which.max(st_length(st_intersection(st_geometry(x)[i], y))) 
                    # [[1]] to get the list element with the intersecting msoas
                    # nrst is assigned to the msoa return from a
                    nrst =  nrst[[1]][a]
                    msoa_code = as.character(y$msoa11cd[nrst[[1]]])
                  } 
                  # if edge falls completely inside 1 msoa, assign it to that msoa
                  else {
                    msoa_code = as.character(y$msoa11cd[nrst[[1]]])
                  }
                  # in all cases above, we get the msoa code by pointing to df$column[row number],
                  # where row number is retrieved from the nrst list through nrst[[1]]....ropey
                  return(msoa_code)
                })
  )
  out = dplyr::as_tibble(out)
  return(out)
}

# use function to assign each edge to an msoa. length of result = length of x
edge_msoas <- assign_edge_to_polygon(x =road_segments, y = msoa_borders, z = nodes)
# rename the column before binding
edge_msoas <- edge_msoas %>% rename(assigned_msoa = value) 

# bind results to original road_segments sf
road_segments <- dplyr::bind_cols(road_segments, edge_msoas)

# plot for quick inspection
plot(st_geometry(msoa_borders))
plot(st_geometry(nodes), col = "grey", add = TRUE)
plot(road_segments['assigned_msoa'], add=TRUE)

###### 2.2: ASSIGN EACH EDGE TO THE SAME COMMUNITY AS ITS ASSOCIATED MSOA #######

road_segments <- road_segments %>% dplyr::left_join(community_assignment, by =  c("assigned_msoa" = "name"))

# quick plot
plot(road_segments['group'])

#################### 3. MAPPING  ######################

# 3.1. map of msoa centroids colored by community

# convert to character for legend
nodes$Community <- as.character(nodes$group)

tm_shape(msoa_borders) +
  tm_borders(col = "grey80") +
  tm_shape(nodes) +
  tm_dots(col = "Community",
          size = 0.1,
          palette = "Dark2") +
  tm_layout(fontfamily = 'Georgia',
            legend.show = FALSE,
            frame = FALSE) -> tm1

# 3.2. map of road segments colored by community

# convert group column to categorical so that we don't get 1-1.5, 2-2.5 etc in the legend
road_segments$Community <- as.character(road_segments$group)

tm_shape(road_segments) +
  tm_lines(#title = "Community",
          col = "Community",
          palette = "Dark2") +
  tm_layout(fontfamily = 'Georgia',
            legend.show =FALSE,
            frame = FALSE) +
  tm_scale_bar(color.dark = "gray60") -> tm2

# 3.3  get legend only for facet map
tm_shape(road_segments) +
  tm_lines(col = "Community",
           palette = "Dark2") +
  tm_layout(fontfamily = 'Georgia',
            legend.only=TRUE,
            frame = FALSE) -> tm_leg

# can do a tmap arrange here but am I bovered?!
tm_facet <- tmap_arrange(tm1, tm2, tm_leg, nrow=1)

#save
tmap_save(tm = tm_facet, filename = paste0("data/", chosen_city,"/Plots/communities_", chosen_city, ".png"), 
          width=8.5, height=4)


# 3.4  MSOAs as cloropleth/choropleth/whatever

# add communitiy column to polygon geometry to create cloropleth map
msoa_borders <- nodes %>% 
  st_drop_geometry %>% 
  dplyr::select(msoa11cd, Community) %>%
  right_join(msoa_borders, by = 'msoa11cd') %>%
  st_as_sf()


tm_shape(msoa_borders) +
  tm_fill(col = "Community",
             palette = "Dark2") +
  tm_layout(fontfamily = 'Georgia',
            legend.show = FALSE,
            frame = FALSE) -> tm3

tm_facet2 <- tmap_arrange(tm3, tm2, tm_leg, nrow=1)

tmap_save(tm = tm_facet2, filename = paste0("data/", chosen_city,"/Plots/communities_alternative_", chosen_city, ".png"), 
          width=8.5, height=4)


# tmap with only the filled out MSOAs 
tm_shape(msoa_borders) +
  tm_fill(col = "Community",
          palette = "Dark2") +
  tm_layout(fontfamily = 'Georgia',
            frame = FALSE) +
  tm_scale_bar(color.dark = "gray60") -> tm_single

tmap_save(tm = tm_single, filename = paste0("data/", chosen_city,"/Plots/communities_msoas", chosen_city, ".png"))



# save road_segments as an RDS to work with in the next script
saveRDS(road_segments, file = paste0("data/", chosen_city, "/graph_with_flows_weighted_communities.Rds"))

# CLEAR ENVIRONMENT!!!
rm(community_assignment, edge_msoas, edges, graph, graph_louvain, msoa_borders, nodes, road_segments,
   tm_facet, tm_facet2, tm_leg, tm1, tm2, tm3, tm_single, assign_edge_to_polygon)

# to check which features do not intersect at all with MSOAS #id:423
# mapview::mapview(road_segments, zcol="assigned_msoa") + 
#   mapview::mapview(msoa_borders)




