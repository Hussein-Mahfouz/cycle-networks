library(tidyverse)
library(sf)
library(tmap)


graph_sf_weighted <- readRDS(paste0("data/", chosen_city,"/graph_with_flows_weighted.Rds"))
graph_sf_unweight <- readRDS(paste0("data/", chosen_city,"/graph_with_flows_unweighted.Rds"))
#graph_sf_trunk <- readRDS(paste0("data/", chosen_city,"/graph_with_flows_trunk.Rds"))


plot(graph_sf_weighted['flow'])

# we want to know the total person-kilometres traveled on each road type
# 1. multiply flow by distance to get person-km on each edge
# 2. group by highway type
# 3. get total and % of person-km on each highway type

dist_weight <- graph_sf_weighted %>% st_drop_geometry() %>%
  # we add the weighted-distance column before grouping because we can't get it after grouping
  mutate(sum_weighted_dist = sum(d*flow)) %>%   
  group_by(highway) %>%
  summarize(dist = sum(d*flow) /1000,         # this is the total person-km per highway type
            dist_perc = ((sum(d*flow)) / mean(sum_weighted_dist)) * 100) %>% #same as above but as %
  mutate(weighting = 'weighted')


dist_unw <- graph_sf_unweight %>% st_drop_geometry() %>%
  mutate(sum_weighted_dist = sum(d*flow)) %>%   
  group_by(highway) %>%
  summarize(dist = sum(d*flow) /1000,         
            dist_perc = ((sum(d*flow)) / mean(sum_weighted_dist)) * 100) %>% 
  mutate(weighting = 'unweighted')


# dist_tr <- graph_sf_trunk %>% st_drop_geometry() %>%
#   mutate(sum_weighted_dist = sum(d*flow)) %>%   
#   group_by(highway) %>%
#   summarize(dist = sum(d*flow) /1000,         
#             dist_perc = ((sum(d*flow)) / mean(sum_weighted_dist)) * 100) %>% 
#   mutate(weighting = 'trunk permitted')


# remove some highway types

person_km <- rbind(dist_weight, dist_unw)
 
# exploratory plot
ggplot(data=dist_weight, aes(x=highway, y=dist_perc))+
  geom_col() + coord_flip()

#remove highway types that have very little share (for plotting purposes)
person_km <- person_km %>% 
  dplyr::filter(!(highway %in% c('trunk_link', 'track', 'tertiary_link', 'steps', 
                               'secondary_link', 'primary_link', 'living_street',
                               'motorway_link')))

# plot % of person-km on each highway type
ggplot(data=person_km , aes(x=highway, y=dist_perc, group=factor(weighting), fill=factor(weighting))) +
    geom_col(position=position_dodge(0.7), colour="black") +
    ggtitle("Percentage of Total Flow Traversing Different Highway Types") +
    labs(x = "Highway Type", y = "% of Total Flow", fill = "weighting") +
    scale_y_continuous(labels = scales::comma_format()) +                         # add comma to y labels
    scale_fill_brewer(palette = "Greys", name="Weighting Profile" , direction=-1) +                                        # for nice color schemes
    # edit angle of text, hjust argument so that text stays below plot AND center plot title
    theme_minimal() +
    #theme(axis.text.x = element_text(angle=50, hjust=1), plot.title = element_text(hjust = 0.5)) + 
    coord_flip() -> p
p

ggsave(path = paste0("data/", chosen_city,"/Plots"), 
       file=paste0("perc_person-km-per-highway-type_", chosen_city, ".png"), p, width = 10, height = 6)


# plot person-km on each highway type
ggplot(data=person_km , aes(x=highway, y=dist, group=factor(weighting), fill=factor(weighting))) +
  geom_col(position=position_dodge(0.7), colour="black") +
  ggtitle("Total Person KM Traversing \nDifferent Highway Types") +
  labs(x = "Highway Type", y = "Distance (km) Weighted By Flow", fill = "weighting") +
  scale_y_continuous(labels = scales::comma_format()) +                         # add comma to y labels
  scale_fill_brewer(palette = "Greys", name="Weighting Profile", direction=-1) +          # for nice color schemes
  theme_minimal() +
  # edit angle of text, hjust argument so that text stays below plot AND center plot title
  theme(axis.text.x = element_text(angle=30, hjust=1), plot.title = element_text(hjust = 0.5)) + 
  coord_flip() -> p

p

ggsave(path = paste0("data/", chosen_city,"/Plots"), 
       file=paste0("person-km-per-highway-type_", chosen_city, ".png"), p, width = 10, height = 6)



###### PLOT HIGHWAY TYPES ######

# I am not plotting the graph directly as it only has the roads that had flow. I will download the OSM
# data and filter it to the bounding box of the graph
# get bounding box for downloading data

#get bb
pts <- st_coordinates(graph_sf_weighted)
# download using dodgr
roads <- dodgr_streetnet(pts = pts, expand = 0) 
# filter to graph boundary 
roads <- st_filter(roads, graph_sf_weighted)

x <- roads %>% 
  dplyr::filter(!(highway %in% c('trunk_link', 'track', 'tertiary_link', 'steps', 
                                 'secondary_link', 'primary_link', 'living_street',
                                 'motorway_link', 'path', 'service', 'unclassified',
                                  NA, 'road')))

tm_shape(x) +
  tm_lines(col = 'gray95') +
tm_shape(x) +
  tm_lines(col = 'highway', 
           scale = 1.5,     #multiply line widths by 3
           palette = "Set2") +
  tm_layout(title = "OSM Road Types - All Roads",        
            title.size = 1.2,
            title.color = "azure4",
            title.position = c("left", "top"),
            inner.margins = c(0.1, 0.25, 0.1, 0.1),    # bottom, left, top, and right margin
            fontfamily = 'Georgia',
            #legend.position = c("right", "bottom"),
            frame = FALSE) -> p

tmap_save(tm = p, filename = paste0("data/", chosen_city,"/Plots/osm_road_types_all.png"))


#### Roads with Routed Flow Only 

#remove highway types that have very little share (for plotting purposes)
x <- graph_sf_weighted %>% 
  dplyr::filter(!(highway %in% c('trunk_link', 'track', 'tertiary_link', 'steps', 
                                 'secondary_link', 'primary_link', 'living_street',
                                 'motorway_link', 'path', 'service', 'unclassified')))

tm_shape(x) +
  tm_lines(col = 'gray95') +
  tm_shape(x) +
  tm_lines(col = 'highway', 
           scale = 1.5,     #multiply line widths by 3
           palette = "Set2") +
  tm_layout(title = "OSM Road Types - Only Roads with Routed Flow",        
            title.size = 1.2,
            title.color = "azure4",
            title.position = c("left", "top"),
            inner.margins = c(0.1, 0.25, 0.1, 0.1),    # bottom, left, top, and right margin
            fontfamily = 'Georgia',
            #legend.position = c("right", "bottom"),
            frame = FALSE) -> p

tmap_save(tm = p, filename = paste0("data/", chosen_city,"/Plots/osm_road_types_routed.png"))



#### FACET PLOT OF ROAD TYPES ####

tm_shape(x) +
  tm_lines(col = "darkgrey") +    
  tm_facets(by="highway",
            nrow = 2,
            free.coords=FALSE)  +  # so that the maps aren't different sizes
  tm_layout(fontfamily = 'Georgia',
            main.title = "Road Types", # this works if you need it
            main.title.size = 1.2,
            main.title.color = "azure4",
            main.title.position = "left",
            legend.outside.position = "bottom" , 
            legend.outside.size = .1,
            #inner.margins = c(0.01, 0.01, 0.01, 0.01),
            frame = FALSE)  -> p

tmap_save(tm = p, filename = paste0("data/", chosen_city,"/Plots/osm_road_types_facet.png"),
          width=10, height=6)



###### FACET PLOT OF FLOWS. works but v slow (2 mins) ######
# 1. default weighting
facet_1 <- graph_sf_weighted %>% 
  dplyr::filter(!(highway %in% c('trunk_link', 'track', 'tertiary_link', 'steps', 
                                 'secondary_link', 'primary_link', 'living_street',
                                 'motorway_link', 'path', 'service', 'unclassified'))) 
tm_shape(facet_1) +
    tm_lines(col = 'gray92') +
tm_shape(facet_1) +
    tm_lines(lwd = "flow",
             scale = 8,  #multiply line widths by scale
             col = "darkgreen") +    
    tm_facets(by="highway",
              nrow = 2,
              free.coords=FALSE)  +  # so that the maps aren't different sizes
    tm_layout(fontfamily = 'Georgia',
              main.title = "Flow on Weighted Network", # this works if you need it
              main.title.size = 1.3,
              main.title.color = "azure4",
              main.title.position = "left",
              legend.outside.position = "bottom" , 
              legend.outside.size = .1,
              #inner.margins = c(0.01, 0.01, 0.01, 0.01),
              frame = FALSE)  -> p

tmap_save(tm = p, filename = paste0("data/", chosen_city,"/Plots/flows_facet_weighted_", chosen_city, ".png"), 
          width=10, height=6)


# 2. Unweighted
facet_2 <- graph_sf_unweight %>% 
  dplyr::filter(!(highway %in% c('trunk_link', 'track', 'tertiary_link', 'steps', 
                                 'secondary_link', 'primary_link', 'living_street',
                                 'motorway_link', 'path', 'service', 'unclassified'))) 

tm_shape(facet_2) +
  tm_lines(col = 'gray92') +
tm_shape(facet_2) +
  tm_lines(lwd = "flow",
           scale = 8,  #multiply line widths by scale
           col = "darkgreen") +    
tm_facets(by="highway",
          nrow = 2,
          free.coords=FALSE)  +  # so that the maps aren't different sizes
tm_layout(fontfamily = 'Georgia',
          main.title = "Flow on Unweighted Network", # this works if you need it
          main.title.size = 1.3,
          main.title.color = "azure4",
          main.title.position = "left",
          legend.outside.position = "bottom" , 
          legend.outside.size = .1,
          frame = FALSE)  -> p

tmap_save(tm = p, filename = paste0("data/", chosen_city,"/Plots/flows_facet_unweighted_", chosen_city, ".png"), 
          width=10, height=6)

# 3. Trunk weight
# facet_3 <- graph_sf_trunk %>% 
#   dplyr::filter(!(highway %in% c('trunk_link', 'track', 'tertiary_link', 'steps', 
#                                  'secondary_link', 'primary_link', 'living_street',
#                                  'motorway_link', 'path', 'service', 'unclassified'))) 
# tm_shape(facet_3) +
#   tm_lines(col = 'gray92') +
# tm_shape(facet_3) +
#   tm_lines(lwd = "flow",
#            scale = 8,  #multiply line widths by scale
#            col = "darkgreen") +    
# tm_facets(by="highway",
#           nrow = 2,
#           free.coords=FALSE)  +  # so that the maps aren't different sizes
# tm_layout(fontfamily = 'Georgia',
#           main.title = "Reduced Impedence on Trunk Roads", # this works if you need it
#           main.title.size = 1.3,
#           main.title.color = "azure4",
#           main.title.position = "left",
#           legend.outside.position = "bottom" , 
#           legend.outside.size = .1,
#           frame = FALSE)  -> p
# 
# tmap_save(tm = p, filename = paste0("data/", chosen_city,"/Plots/flows_facet_trunk.png"), 
#           width=10, height=6)



# Facet map with one road type and different weighting profiles

road_type <- "trunk"
# this needs to be edited manually based on the road type and observing the ranges of the different plots
lwd_legend = c(250, 500, 750, 1000, 1500, 2000)

plot1 <- graph_sf_weighted %>% 
  dplyr::filter(highway == road_type)

tm_shape(facet_1) +
  tm_lines(col = 'gray92') +
tm_shape(plot1) +
  tm_lines(lwd = "flow",
           #lwd.legend = lwd_legend,
           scale = 3,  #multiply line widths by scale
           col = "darkgreen") +    
tm_layout(fontfamily = 'Georgia',
            title = "Weighted", # this works if you need it
            title.size = 1,
            title.color = "azure4",
            #inner.margins = c(0, 0, 0.03, 0),
            #legend.outside = TRUE,
            #legend.outside.position = "bottom",
            #legend.title.size=0.85,
            legend.show = FALSE,
            #legend.position = c("right", "bottom"),
            frame = FALSE)  -> p1

plot2 <- graph_sf_unweight %>% 
  dplyr::filter(highway == road_type)

tm_shape(facet_2) +
  tm_lines(col = 'gray92') +
  tm_shape(plot2) +
  tm_lines(lwd = "flow",
           #lwd.legend = lwd_legend,
           scale = 3,  #multiply line widths by scale
           col = "darkgreen",
           legend.lwd.is.portrait = TRUE) +    
  tm_layout(fontfamily = 'Georgia',
            title = "Unweighted", 
            title.size = 1,
            title.color = "azure4",
            #inner.margins = c(0, 0, 0.05, 0),
            #legend.outside = TRUE,
            #legend.outside.position = "right",
            #legend.title.size=0.85,
            legend.show = FALSE,
            #legend.position = c("right", "bottom"),
            frame = FALSE)  +
   tm_scale_bar(color.dark = "gray60") -> p2

# plot3 <- graph_sf_trunk %>% 
#   dplyr::filter(highway == road_type)
# 
# tm_shape(facet_3) +
#   tm_lines(col = 'gray92') +
#   tm_shape(plot2) +
#   tm_lines(lwd = "flow",
#            #lwd.legend = lwd_legend,
#            scale = 3,  #multiply line widths by scale
#            col = "darkgreen") +    
#   tm_layout(fontfamily = 'Georgia',
#             title = "Trunk Permitted", # this works if you need it
#             title.size = 1,
#             title.color = "azure4",
#             #inner.margins = c(0, 0, 0.03, 0),
#             #legend.outside = TRUE,
#             #legend.outside.position = "bottom",
#             #legend.title.size=0.85,
#             legend.show = FALSE,
#             #legend.position = c("right", "bottom"),
#             frame = FALSE)  -> p3

### legend only 
tm_shape(plot1) +
  tm_lines(lwd = "flow",
           scale = 3,  
           col = "darkgreen",
           legend.lwd.is.portrait = TRUE) +    
  tm_layout(fontfamily = 'Georgia',
            legend.position = c("left", "top"),
            legend.title.size=0.85,
            legend.only = TRUE)  -> legend

facet_road_type <- tmap_arrange(p1, p2, legend, nrow=1)


tmap_save(tm = facet_road_type, filename = paste0("data/", chosen_city,"/Plots/", road_type, chosen_city, "_facet.png"),
          height=4, width= 9)


rm(dist_def, dist_tr, dist_unw, dist_weight,facet_1, facet_2, facet_3, facet_road_type, graph_sf_default,
   graph_sf_trunk, graph_sf_unweight, graph_sf_weighted, legend, p, p1, p2, p3, person_km, plot1, plot2, plot3, 
   pts, roads, x, lwd_legend, road_type)



