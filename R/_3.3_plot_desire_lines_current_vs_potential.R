library(tidyverse)
library(pct)
library(stplanr)
library(tmap)
library(lwgeom)
library(sf)

# This script depends on data from Script 1, 2 and 3

##### READ IN DATA #####

# FLOW DATA
# get the flow for the chosen city: data retrieved in Script 1 _1_get_flow_data
city_od <- readr::read_csv(paste0("data/", chosen_city, "/flows_city.csv"))

# MSOA CODES
# get the MSOA codes of MSOAs in the chosen city. Data retrieved from _2_distance_and_elevation
city_msoas <- readr::read_csv(paste0("data/",chosen_city,"/msoa_codes_city.csv"))

# MSOA CENTROIDS
# get population weighted centroids from pct and change crs (default is northing)
city_centroids <- pct::get_centroids_ew() %>% st_transform(4326)
# keep only centroids of chosen city 
city_centroids <- city_centroids %>% dplyr::filter(msoa11cd %in% city_msoas$MSOA11CD)

# MSOA BOUNDARIES
#get msoa boundaries for plotting 
city_geom <- sf::st_read("data-raw/MSOA_2011_Boundaries/Middle_Layer_Super_Output_Areas__December_2011__Boundaries.shp") %>%
  st_transform(4326)
# filter only MSOAs in the city_msoas df
city_geom <- city_geom %>% dplyr::filter(msoa11cd %in% city_msoas$MSOA11CD)

#POTENTIAL FLOW (Script 3)
city_potential_cycling <- read_csv(paste0("data/",chosen_city, "/flows_for_aggregated_routing_opt_3.csv"))
# add potential flow column to city_od df
city_od <- city_od %>% left_join(city_potential_cycling, 
                                 by = c("Area of residence" = "Area of residence", 
                                        "Area of workplace" = "Area of workplace"))
# some OD pairs don't exist in potential flow. It means they have 0 potential flow
city_od$potential_demand[is.na(city_od$potential_demand)] <- 0


# get straight line geometry of all OD pairs in city_od
desire_lines <- stplanr::od2line(city_od, city_centroids)
desire_lines <- sf::st_make_valid(desire_lines)

# filter out all OD pairs with flow less than this:
flow_threshold_all <- 50

desire_lines_all <- desire_lines %>% 
  dplyr::filter(`All categories: Method of travel to work` >= flow_threshold_all)

# plot all flows
tm_shape(city_geom) +
  tm_borders(col = "grey80", 
             lwd = 1, 
             alpha = 0.5) +
tm_shape(desire_lines_all) +
  tm_lines(title.col = "Flow - All Modes",
           legend.lwd.show = FALSE,   # remove lineweight legend
           lwd = "All categories: Method of travel to work",
           col = "All categories: Method of travel to work",
           palette = "YlOrRd",
           style = "pretty",
           scale = 9) +
  tm_layout(fontfamily = 'Georgia',
            frame = FALSE)
  

# plot for cycling ridership
flow_threshold_cycling <- 5

desire_lines_cycling <- desire_lines %>% 
  dplyr::filter(Bicycle >= flow_threshold_cycling)

# plot cycling flows
tm_shape(city_geom) +
  tm_borders(col = "grey80", 
             lwd = 1, 
             alpha = 0.5) +
  tm_shape(desire_lines_cycling) +
  tm_lines(title.col = "Flow - Cycling",
           legend.lwd.show = FALSE,   # remove lineweight legend
           lwd = "Bicycle",
           col = "Bicycle",
           palette = "YlOrRd",
           style = "pretty",
           scale = 9) +
  tm_layout(fontfamily = 'Georgia',
            frame = FALSE)

desire_cycling_long <- desire_lines_cycling %>% 
  dplyr::select(`Area of residence`, `Area of workplace`, Bicycle, potential_demand) 
# pivot for facet plot 
desire_cycling_long <- desire_cycling_long %>% pivot_longer(cols = c(Bicycle, potential_demand)) %>%
  st_as_sf()



###### FACET PLOT OF CURRENT AND POTENTIAL CYCLING DEMAND ######

tm_shape(city_geom) +
  tm_borders(col = "grey80", 
             lwd = 1, 
             alpha = 0.5) +
tm_shape(desire_cycling_long) +
  tm_lines(title.col = "Cycling Demand (Commuters)",
           lwd = "value",
           col= "value",
           palette = "YlOrRd",
           style = "pretty",
           scale = 5,
           legend.col.is.portrait = FALSE,
           legend.lwd.show = FALSE) +   # remove lineweight legend) 
  tm_facets(by="name",
            nrow = 1,
            free.coords=FALSE) +  # so that the maps aren't different sizes
  tm_layout(fontfamily = 'Georgia',
            panel.labels = c('Existing Cycling Demand', 'Potential Cycling Demand'),
            panel.label.size = 1.3,
            frame.lwd = NA,    # remove facet title frames
            panel.label.bg.color = NA,   # remove facet title background
            legend.outside = TRUE,
            legend.outside.position = 'bottom',
            frame = FALSE) +
  tm_scale_bar(color.dark = "gray60") + 
  tm_compass(type = "arrow",
             size = 1,
             show.labels = 0,
             position = c("right","top"),
             color.dark = "gray60") -> p

#save
tmap_save(tm = p, filename = paste0("data/", chosen_city,"/Plots/desire_facet_cycling.png"), 
          width=8, height=6)

# clear environment
rm(city_centroids, city_geom, city_msoas, city_od, city_potential_cycling, desire_cycling_long, 
   desire_lines, desire_lines_all, desire_lines_cycling, flow_threshold_all, flow_threshold_cycling, p)

