library(sf)
library(sfnetworks)
library(tidyverse)
library(ggtext)
library(igraph)
library(tmap)

#create a directory to store data related to this city (does nothing if directory already exists)
dir.create(paste0("data/", chosen_city, "/Plots/Growth_Results"), showWarnings = FALSE)

graph_sf <- readRDS(paste0("data/", chosen_city, "/graph_with_flows_weighted_communities.Rds"))

# we weigh the flow on each edge by its distance. We can then get how much of the commuter km are satisfied
graph_sf$person_km <- graph_sf$flow * graph_sf$d

# check how many person-km in each Community 
graph_sf %>% 
  st_drop_geometry %>% 
  group_by(Community) %>% 
  summarize(total_person_km = sum(person_km) / 1000) %>% 
  mutate(perc_person_km = (total_person_km / sum(total_person_km) * 100)) 


# get percentage contibution of each edge to the network (distance, flow, person_km)
graph_sf <- graph_sf %>%
  mutate(perc_dist = (d/sum(d))  *100,      # edge length as % of total network length
         perc_flow = (flow/sum(flow))  *100, # flow on edge as % of total
         perc_person_km = (person_km/sum(person_km))  *100) %>% # % of person_km satisfied
  # get the same % for each community as a % of the community totals
  group_by(Community) %>%
  mutate(perc_dist_comm = (d/sum(d)) * 100,  
         perc_flow_comm = (flow/sum(flow))  *100,
         perc_person_km_comm = (person_km/sum(person_km))  *100) %>%
  ungroup()

################
# get no. of km of road network without cycling infrastructure (to add as a variable to the growth functions)
cycle_infra <- graph_sf %>% dplyr::filter(cycle_infra == 1) 
# total length of edges without cycling infrastructure
no_cycle_infra <- round((sum(graph_sf$d) - sum(cycle_infra$d))  / 1000)
# subtract 5km just to be safe. I don't want the growth functions to iterate exactly to the network length
no_cycle_infra <- no_cycle_infra - 5
################


# ----------------------------------- ALGORITHM 1: UTILITARIAN GROWTH ----------------------------------------- #

# let's grow the network from the existing infrastructure
grow_util <- growth_utilitarian(graph = graph_sf, km = no_cycle_infra, col_name = "flow")
#save
saveRDS(grow_util, file = paste0("data/", chosen_city, "/growth_util.Rds"))
# read in 
#grow_util <- readRDS(paste0("data/", chosen_city,"/growth_util.Rds"))


# get % of edges in gcc
grow_util$gcc_size_perc <- (grow_util$gcc_size / nrow(graph_sf)) * 100
# prepare a dataframe for ggplot
grow_util_c <- grow_util %>% 
  arrange(sequen) %>%  # make sure it is arranged by sequen (Otherwise cumulative sum values will be wrong)
  ungroup %>%   # not sure why it is a grouped df. This only has an effect on the select argument
  filter(cycle_infra == 0) %>% # all edges with cycle infrastructure were added at the beginning
  dplyr::select(Community, d, flow, highway, cycle_infra, sequen, perc_dist, perc_flow,
                perc_person_km, perc_dist_comm, perc_flow_comm, perc_person_km_comm, no_components,
                gcc_size, gcc_size_perc)


# We have filtered the dataframe to include only segments without cycling infrastructure. This is because we want 
# to see the effect of adding these segments on the person_km satisfied. However, the initial person_km satisfied is not 0
# but equal to that satisfied by existing infrastructure. We calculate those initial values and add them to the cumulative
# percentages calculated

# get the person_km satisfied by existing infrastructure
initial_perc_satisfied_all <- grow_util %>% 
  st_drop_geometry() %>% 
  filter(cycle_infra == 1) %>% 
  summarize(sum(perc_person_km)) %>% as.numeric()
# same as above but for each community
initial_perc_satisfied_comm <- grow_util %>% 
  st_drop_geometry() %>% 
  group_by(Community) %>%
  filter(cycle_infra == 1) %>% 
  summarize(initial_perc_satisfied = sum(perc_person_km_comm))  



# join the community values so that we can add them to cumsum so that % satisfied does not start at 0 
grow_util_c <- grow_util_c %>%
  dplyr::left_join(initial_perc_satisfied_comm, by = c("Community"))

# cumsum is cumulative sum. We see how much of person_km has been satisfied after each iteration 
grow_util_c <- grow_util_c %>%
  mutate(dist_c = cumsum(d/1000),
         perc_dist_c = cumsum(perc_dist),
         perc_person_km_c = cumsum(perc_person_km) + initial_perc_satisfied_all) %>%
  # groupby so that you can apply cumsum by community 
  group_by(Community) %>% 
  mutate(dist_c_comm = cumsum(d/1000),
         perc_dist_comm_c = cumsum(perc_dist_comm),
         perc_person_km_comm_c = cumsum(perc_person_km_comm) + initial_perc_satisfied) %>%
  ungroup()

# add a categorical column to show which investment brack the segment is in (0:100, 100:200 etc)
grow_util_c$distance_groups <- cut(grow_util_c$dist_c, breaks = seq(from = 0, to = max(grow_util_c$dist_c) + 100, by = 100))


# network level plot
ggplot(data=grow_util_c , aes(x=dist_c, y=perc_person_km_c)) +
  geom_line() +
  ggtitle("Algorithm 1 (Utilitarian)") +
  labs(x = "Length of Investment (km)", y = "% of person km satisfied",
       subtitle="Segments Prioritized Based On **Flow**") +
  theme_minimal() +
  theme(plot.title = element_text(size = 14)) +
  theme(plot.subtitle = element_markdown(size = 10)) +
  scale_x_continuous(expand = c(0, 0), limits = c(0, NA)) + 
  scale_y_continuous(expand = c(0, 0), limits = c(0, 100))

ggsave(paste0("data/", chosen_city,"/Plots/Growth_Results/growth_utilitarian_satisfied_km_all_flow_column.png"))

# community level plots
ggplot(data=grow_util_c, 
       aes(x=dist_c, y=perc_person_km_comm_c, group=Community, color = Community)) +
  geom_line() + 
  ggtitle("Algorithm 1 (Utilitarian)") +
  labs(x = "Total Length of Investment (km)", y = "% of person km satisfied within community",
       subtitle="Segments Prioritized Based On **Flow**") +
  theme_minimal() +
  theme(plot.title = element_text(size = 14)) +
  theme(plot.subtitle = element_markdown(size = 10)) +
  scale_x_continuous(expand = c(0, 0), limits = c(0, NA)) + 
  scale_y_continuous(expand = c(0, 0), limits = c(0, 100))

ggsave(paste0("data/", chosen_city,"/Plots/Growth_Results/growth_utilitarian_satisfied_km_community_flow_column.png"))


# both community and network level together

ggplot(data=grow_util_c, mapping=aes(x=dist_c, y = perc_person_km_comm_c)) +
  geom_line(mapping=aes(group=Community, color = Community)) +
  geom_line(mapping=aes(y=perc_person_km_c), color = "grey50", linetype = "dotted", size = 1.1)  + 
  ggtitle("Algorithm 1 (Utilitarian)") +
  labs(x = "Total Length of Investment (km)", y = "% of person km satisfied within community",
       subtitle="Segments Prioritized Based On **Flow**") +
  theme_minimal(base_size = 13) +
  theme(plot.title = element_text(size = 14)) +
  theme(plot.subtitle = element_markdown(size = 10)) +
  scale_x_continuous(expand = c(0, 0), limits = c(0, NA)) + 
  scale_y_continuous(expand = c(0, 0), limits = c(0, 100))

ggsave(paste0("data/", chosen_city,"/Plots/Growth_Results/growth_utilitarian_satisfied_km_both_flow_column.png"))


# network level plot showing no of components (decreasing?) as network grows

# ggplot(data=grow_util_c , aes(x=dist_c, y=no_components)) +
#   geom_line() +
#   ggtitle("Number of Components Making Up Network") +
#   labs(x = "Length of Investment (km)", y = "No. of Components",
#        subtitle=expression("Segments Prioritized Based On **Flow**")) +
#   theme_minimal() +
#   theme(plot.subtitle = element_markdown())

ggplot(data=grow_util_c , aes(x=dist_c, y=no_components)) +
  geom_line() +
  labs(x = "Length of Investment (km)", y = "No. of Components",
       title = "Algorithm 1 (Utilitarian)") +
  theme_minimal() +
  theme(plot.subtitle = element_markdown(size =8))

ggsave(paste0("data/", chosen_city,"/Plots/Growth_Results/growth_utilitarian_components_number_flow_", chosen_city, ".png"))


# network level plot showing size of gcc 

ggplot(data=grow_util_c , aes(x=dist_c, y=gcc_size_perc)) +
  geom_line() +
  labs(x = "Length of Investment (km)", y = "% of Edges in LCC",
       title="Algorithm 1 (Utilitarian)") +
  theme_minimal() +
  theme(plot.subtitle = element_markdown(size = 10))

ggsave(paste0("data/", chosen_city,"/Plots/Growth_Results/growth_utilitarian_components_gcc_flow_", chosen_city, ".png"))


# inverse sequence so that thickest edges are the ones selected first
grow_util_c$sequen_inv <- max(grow_util_c$sequen) - grow_util_c$sequen

# segments that had dedicated cycling infrastructure
initial_infra <- grow_util %>% filter(cycle_infra == 1)

#### Plot with colour proportional to km (from cumulative distance column) instead of sequence  ####
tm_shape(graph_sf) +
  tm_lines(col = 'gray95') +
  tm_shape(initial_infra) +
  tm_lines(col = 'firebrick2',
           lwd = 2) +
  tm_shape(grow_util_c) +
  tm_lines(title.col = "Priority (km)",
           col = 'dist_c',    # could do col='sequen' to 
           lwd = 'sequen_inv',
           scale = 1.8,     #multiply line widths by X
           palette = "-Blues",
           #style = "cont",   # to get a continuous gradient and not breaks
           legend.lwd.show = FALSE) +
  tm_layout(title = "Algorithm 1 (Utilitarian)",        
            title.size = 1.2,
            title.color = "azure4",
            #title.position = c("left", "top"),
            inner.margins = c(0.1, 0.1, 0.1, 0.1),    # bottom, left, top, and right margin
            fontfamily = 'Georgia',
            #legend.position = c("left", "bottom"),
            frame = FALSE) +
  tm_scale_bar(color.dark = "gray60") +
  # add legend for the existing cycling infrastructure
  tm_add_legend(type = "line", labels = 'Existing Cycling Infrastructure', col = 'firebrick2', lwd = 2) -> p

tmap_save(tm = p, filename = paste0("data/", chosen_city,"/Plots/Growth_Results/growth_utilitarian_priority_all_FLOW.png"))


# lets show where the 1st 100km selected are (to show distribution of resources across communities)
grow_util_c_100 <- grow_util_c %>% dplyr::filter(dist_c <= 100)

tm_shape(graph_sf) +
  tm_lines(col = 'gray95') +
  tm_shape(initial_infra) +
  tm_lines(col = 'firebrick2',
           lwd = 1.3) +
  tm_facets(by="Community",
            nrow = 1,
            free.coords=FALSE)  +  # so that the maps aren't different sizes 
  tm_shape(grow_util_c_100) +
  tm_lines(title.col = "Priority (km)",
           col = 'dist_c', 
           lwd = 'sequen_inv',
           scale = 1.2,     #multiply line widths by X
           palette = "-Blues",
           #style = "cont",   # to get a continuous gradient and not breaks
           legend.lwd.show = FALSE) +
  tm_facets(by="Community",
            nrow = 1,
            free.coords=FALSE)  +  # so that the maps aren't different sizes
  tm_layout(main.title = "Algorithm 1 (Utilitarian) - Distribution of Initial 100km of Investment",        
            main.title.size = 1.2,
            main.title.color = "azure4",
            main.title.position = c("left", "top"),
            fontfamily = 'Georgia',
            legend.outside.position = c("right", "bottom"),
            frame = FALSE) +
  # add legend for the existing cycling infrastructure
  tm_add_legend(type = "line", labels = 'Existing Cycling Infrastructure', col = 'firebrick2', lwd = 1.5) -> p


tmap_save(tm = p, filename = paste0("data/", chosen_city,"/Plots/Growth_Results/growth_utilitarian_facet_FLOW_100.png"), 
          width=10, height=4)


# clear environment
rm(graph_sf, grow_util, initial_perc_satisfied_all, initial_perc_satisfied_comm, initial_infra, 
   grow_util_c_100, p, cycle_infra)



