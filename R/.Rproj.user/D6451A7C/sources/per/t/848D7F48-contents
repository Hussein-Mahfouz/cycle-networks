###############################################################################
######### This script plots the data output from _3_potential_demand ##########
###############################################################################
library(tidyverse)
library(sf)
library(tmap)
library(latex2exp)



uptake_decay <- readr::read_csv(paste0("../data/",chosen_city,"/flows_for_desire_lines.csv"))


# turn distance to km
uptake_no_intra <- uptake_decay %>% dplyr::filter(`Area of residence` != `Area of workplace`)

uptake_no_intra$dist <- uptake_no_intra$dist / 1000



######## PLOT 1: DISTANCE VS TOTAL NO OF CYCLISTS #######
# Not informative as Total Commuting Trips are not equal
uptake_no_intra %>% dplyr::filter(dist <= 10) %>%
  ggplot(aes(x = dist, y = Bicycle)) +
  geom_point(color = "darkgrey") +
  geom_smooth(color = "darkred") +
  labs(x="Commuting Distance (km)", y = "Number of Trips Being Cycled",
       title = "Number of Commuting Trips Cycled - All Trips Under 10km")

#### PLOT 2 : DISTANCE VS PERCENTAGE CYCLING
uptake_no_intra %>% dplyr::filter(dist <= 10) %>%
  ggplot(aes(x = dist, y = perc_cycle)) +
  geom_point(color = "darkgrey") +
  geom_smooth(color = "darkred") +
  labs(x="Commuting Distance (km)", y = "Fraction of Trips Being Cycled",
       title = "Fraction of Commuting Trips Cycled - All Trips Under 10km")

##### PLOT 3: GROUPED STATISTICS - DISTANCE #####

# change distance from m to km
uptake_decay$dist <- uptake_decay$dist / 1000
# group data by distance. Change 'by' to edit number of groups
#uptake_decay$distance_groups <- cut(uptake_decay$dist, breaks = seq(from = 0, to = 50, by = 1))

uptake_decay_grouped <- uptake_decay %>%
  group_by(distance_group = as.character(distance_groups)) %>%
  summarise(distance_avg_group   = mean(dist),
            group_perc_cycle = mean(perc_cycle) *100,
            group_prob_cycle = mean(prob_cycle) *100)

# pivot to long format for ggplot with legend/color argument
uptake_distance_long <- uptake_decay_grouped %>% pivot_longer(cols = c(group_perc_cycle, group_prob_cycle)) 

ggplot(uptake_distance_long, aes(x = distance_avg_group, y = value, color = name)) +
  geom_smooth() +
  labs(x="Commuting Distance (km)", y = "% of Trips Cycled",
       title = "Probabilty of Cycling \nBased on Distance and Slope") +
  scale_color_discrete(name = "", labels = c("Actual", "Estimated"))

##### PLOT 4: GROUPED STATISTICS - SLOPE #####

# change slope to %
uptake_decay$slope <- uptake_decay$slope * 100
# create slope groups
uptake_decay$slope_group <- cut(uptake_decay$slope, breaks = seq(from = 0, to = 10, by = 0.25))

# group data by slope groups. Remove low levels of cycling as they distort percentages
uptake_decay_slope <- uptake_decay %>% filter(Bicycle >= 15) %>%
  group_by(slope_group = as.character(slope_group)) %>%
  summarise(slope_avg_group   = mean(slope),
            group_perc_cycle = mean(perc_cycle) *100,
            group_prob_cycle = mean(prob_cycle) *100)

# pivot to long format for ggplot with legend/color argument
uptake_slope_long <- uptake_decay_slope %>% pivot_longer(cols = c(group_perc_cycle, group_prob_cycle)) 


ggplot(uptake_slope_long, aes(x = slope_avg_group, y = value, color = name)) +
  geom_smooth() +
  labs(x="Commuting Distance (km)", y = "Number of Trips Being Cycled",
       title = "Probabilty of Cycling Based on Distance and Slope") + 
  labs(x="Gradient %", y = "% Trips Cycled",
       title = "Probabilty of Cycling Based on Distance and Slope") +
  scale_color_discrete(name = "", labels = c("Actual", "Estimated"))

##### PLOT 5: UNDERPERFORMING VS OVERPERFORMING OD PAIRS #####

# add the group averages to the od data for plotting
uptake_decay <- uptake_decay %>% left_join(uptake_decay_grouped, 
                                           by = c("distance_groups" = "distance_group"))

# get the cycling % of each OD pair as a fraction of the distance_group average cycling %
uptake_decay$ratio <- uptake_decay$perc_cycle /  (uptake_decay$group_perc_cycle / 100)  # /100 as perc_cycler is fraction not %

### 5.1 - GGPLOT ###
#### CHECK THIS BEFORE yOU WRECK THIS
# remove 0 distance because they haven't been ssigned to groups
uptake_gg <- uptake_decay %>% filter(dist<10, dist!=0)

order <- c("0-1 km", "1-2 km", "2-3 km", "3-4 km", "4-5 km", "5-6 km",
           "6-7 km", "7-8 km", "8-9 km", "9-10 km")
ggplot(uptake_gg, aes(x = factor(distance_groups, level = order), y = ratio)) +
  geom_boxplot(outlier.size  = 0) +
  ylim(NA, 5) +
  geom_hline(yintercept=1, linetype="dashed", 
             color = "darkred", size=0.8)

### 5.2 - THEMATIC MAP IT ###

# MSOA CODES
# get the MSOA codes of MSOAs in the chosen city. Data retrieved from _2_distance_and_elevation
city_msoas <- readr::read_csv(paste0("../data/",chosen_city,"/msoa_codes_city.csv"))

# MSOA CENTROIDS
# get population weighted centroids from pct and change crs (default is northing)
city_centroids <- pct::get_centroids_ew() %>% st_transform(4326)
# keep only centroids of chosen city 
city_centroids <- city_centroids %>% dplyr::filter(msoa11cd %in% city_msoas$MSOA11CD)

# MSOA BOUNDARIES
#get msoa boundaries for plotting 
city_geom <- sf::st_read("../data-raw/MSOA_2011_Boundaries/Middle_Layer_Super_Output_Areas__December_2011__Boundaries.shp") %>%
  st_transform(4326)
# filter only MSOAs in the city_msoas df
city_geom <- city_geom %>% dplyr::filter(msoa11cd %in% city_msoas$MSOA11CD)


# get straight line geometry of all OD pairs. Added as a geometry column
uptake_decay <- stplanr::od2line(uptake_decay, city_centroids)
uptake_decay <- lwgeom::st_make_valid(uptake_decay)

# keep only od pairs <10km
uptake_plot <- uptake_decay %>% filter(dist <= 10)


# # plot all flows

# tm_shape(city_geom) +
#   tm_borders(col = "grey80", 
#              lwd = 1, 
#              alpha = 0.5) +
#   tm_shape(uptake_plot) +
#   tm_lines(title.col = "Ratio: OD Pair Cycling Mode Share / \nGroup Average Cycling Mode Share",
#            legend.lwd.show = FALSE,   # remove lineweight legend
#            #lwd = "perc_cycle",
#            lwd = 0.7,
#            #lwd = "ratio",
#            col = "ratio",
#            breaks = c(0, 0.2, 0.5, 1, 3, 10),
#            midpoint = 1,     # the color palette will split at this point
#            style = "fixed",
#            #palette = "RdYlGn",
#            palette = c('#d7191c', '#fdae61', '#ffffbf', '#a6d96a', '#1a9641'),
#            #style = "pretty",
#            scale = 2) +
#   tm_facets(by="distance_groups",
#             nrow = 2,
#             free.coords=FALSE,
#             showNA = FALSE) +
#   tm_layout(fontfamily = 'Georgia',
#             main.title = 'Comparison of Cycling Uptake Across the City', 
#             main.title.color = 'grey50',
#             legend.title.size = 0.8,
#             frame = FALSE) -> p

tm_shape(city_geom) +
  tm_borders(col = "grey80", 
             lwd = 1, 
             alpha = 0.5) +
  tm_shape(uptake_plot) +
  tm_lines(#title.col = "Ratio: OD Pair Cycling Mode Share / \nGroup Average Cycling Mode Share",
    #title.col = TeX("$\\alpha_{ij} = \\phi(c_{ij}) / P(c_{ij})$"),
    #title.col = TeX("Performance ($\\alpha_{ij})$"),
    title.col = expression(paste("Performance (", alpha[ij],")")),
    legend.lwd.show = FALSE,   # remove lineweight legend
    #lwd = "perc_cycle",
    lwd = 0.7,
    #lwd = "ratio",
    col = "performance",
    breaks = c(0, 0.2, 0.5, 1, 3, 10),
    midpoint = 1,     # the color palette will split at this point
    style = "fixed",
    #palette = "RdYlGn",
    palette = c('#d7191c', '#fdae61', '#ffffbf', '#a6d96a', '#1a9641'),
    #style = "pretty",
    scale = 2) +
  tm_facets(by="distance_groups",
            nrow = 2,
            free.coords=FALSE,
            showNA = FALSE) +
  tm_layout(fontfamily = 'Georgia',
            main.title = paste0('Comparison of Cycling Uptake Across ', chosen_city), 
            main.title.color = 'grey50',
            legend.title.size = 0.8,
            frame = FALSE) -> p

#save
tmap_save(tm = p, filename = paste0("../data/", chosen_city,"/Plots/facet_desire_lines_all.png"), 
          width=9, height=4)


# keep only underperforming OD pairs
uptake_low <- uptake_plot %>% filter(ratio < 1)  

tm_shape(city_geom) +
  tm_borders(col = "grey80", 
             lwd = 1, 
             alpha = 0.5) +
  tm_shape(uptake_low) +
  tm_lines(title.col = "Ratio: OD Pair Cycling Mode Share / \nGroup Average Cycling Mode Share",
           legend.lwd.show = FALSE,   # remove lineweight legend
           lwd = 0.7,
           col = "ratio",
           breaks = c(0, 0.2, 0.5, 0.8, 1),
           style = "fixed",
           palette = "-OrRd",
           scale = 2) +
  tm_facets(by="distance_groups",
            nrow = 2,
            free.coords=FALSE,
            showNA = FALSE) +
  tm_layout(fontfamily = 'Georgia',
            main.title = 'OD Pairs with Cycling Mode Share Below Group Average', 
            main.title.color = 'grey50',
            frame = FALSE) -> p

#save
tmap_save(tm = p, filename = paste0("../data/", chosen_city,"/Plots/facet_desire_lines_below_avg.png"), 
          width=9, height=4)


# keep only overperforming OD pairs
uptake_high <- uptake_plot %>% filter(ratio >= 1)  

tm_shape(city_geom) +
  tm_borders(col = "grey80", 
             lwd = 1, 
             alpha = 0.5) +
  tm_shape(uptake_high) +
  tm_lines(title.col = "Ratio: OD Pair Cycling Mode Share / Group Average Cycling Mode Share",
           legend.lwd.show = FALSE,   # remove lineweight legend
           lwd = 0.7,
           col = "ratio",
           breaks = c(1, 2, 5, 8, 10),
           style = "fixed",
           palette = "GnBu",
           scale = 2) +
  tm_facets(by="distance_groups",
            nrow = 2,
            free.coords=FALSE,
            showNA = FALSE) +
  tm_layout(fontfamily = 'Georgia',
            main.title = 'OD Pairs with Cycling Mode Share Above Group Average', 
            main.title.color = 'grey50',
            frame = FALSE) -> p

#save
tmap_save(tm = p, filename = paste0("../data/", chosen_city,"/Plots/facet_desire_lines_above_avg.png"), 
          width=9, height=4)


##### PLOT 6: DISTRIBUTION OF ADDITIONAL FLOWS #####

# get data in long format for ggplot
uptake_decay %>% st_drop_geometry() %>% 
  select(dist, perc_cycle, cycle_fraction) %>%
  mutate(perc_cycle = perc_cycle*100,
         cycle_fraction = cycle_fraction*100) %>%
  pivot_longer(cols = c(perc_cycle, cycle_fraction)) -> p

# plot
ggplot(p, aes(x= dist, y=value, color = name)) +
  geom_smooth() + 
  labs(title = paste0('Distribution of Cycling Increase \nif Mode Share Reaches ', round(cycle_target*100), '%'),
       x="Commuting Distance (km)", y = "Cycling Mode Share (%)") + 
  scale_color_manual(name = "", labels = c("Potential", "Current"), values=c("darkgreen", "darkred")) +
  theme_minimal() #+
  #ylim(0, NA)
  
#save
ggsave(paste0("../data/", chosen_city,"/Plots/cycling_increase_line.png"), width = 6, height = 6)




# clear environment
rm(city_centroids, city_geom, city_msoas, p, uptake_decay, uptake_decay_grouped, 
   uptake_decay_slope, uptake_distance_long, uptake_gg, uptake_high, uptake_low, 
   uptake_no_intra, uptake_plot, uptake_slope_long, cycle_target, order)

