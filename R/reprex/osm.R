library(sf)
library(dodgr)
library(tidyverse)


#this downloads all the road data from OSM (equivalent to : key = 'highway')
streetnet <- dodgr_streetnet("manchester uk", expand = 0.05)

# filter out useful columns
streetnet2 <- streetnet %>% 
  dplyr::select(osm_id, bicycle, cycleway, highway,
                lanes, segregated)
# add length column
streetnet2 <- streetnet2 %>% dplyr::mutate(length_m = st_length(.))

# check different columns

#highway column
streetnet2 %>% 
  st_drop_geometry() %>%
  group_by(highway) %>% 
  summarize(segments=n(), `length (m)` = sum(length_m))

# get all the highway types
unique(streetnet2$highway)

# bicycle column
streetnet2 %>% 
  st_drop_geometry() %>%
  group_by(bicycle) %>% 
  summarize(segments=n(), `length (m)` = sum(length_m))

#cycleway column
streetnet2 %>% 
  st_drop_geometry() %>%
  group_by(cycleway) %>% 
  summarize(segments=n(), `length (m)` = sum(length_m))

#lanes column
streetnet2 %>% 
  st_drop_geometry() %>%
  group_by(lanes) %>% 
  summarize(segments=n(), `length (m)` = sum(length_m))

#segregated column
streetnet2 %>% 
  st_drop_geometry() %>%
  group_by(segregated) %>% 
  summarize(segments=n(), `length (m)` = sum(length_m))

# How is bicycle=designated different to highway=cycleway

# bicycle=designated
bicycle_designated <- streetnet2 %>% filter(bicycle == 'designated')
plot(st_geometry(bicycle_designated))
# highway=cycleway
high_cycleway <- streetnet2 %>% filter(highway == 'cycleway')
plot(st_geometry(high_cycleway))

# designated bicycle lanes that do not have cycleway tag
lane_not_cycleway <- streetnet2 %>% filter(bicycle == 'designated', highway != 'cycleway')
plot(st_geometry(lane_not_cycleway))
# cycleways that do not have designated bicycle lane tag
cycleway_not_designated <- streetnet2 %>% filter(bicycle != 'designated', highway == 'cycleway')
plot(st_geometry(cycleway_not_designated))

# Plot all highway=cycleway
plot(st_geometry(cycleways))

#highway=cycleway
plot(st_geometry(cycleways))
#bicycle=designated
plot(st_geometry(bicycle_designated), add = TRUE, col = 'red')

# Out of all the geometries that match bicycle=designated, only the red one are not cycleways.
# This shows that the highway=cycleway alone does not covered all cycle lanes
#bicycle=designated
plot(st_geometry(bicycle_designated))
#bicycle=designated BUT highway != cycleway
plot(st_geometry(lane_not_cycleway), add = TRUE, col = 'red')


