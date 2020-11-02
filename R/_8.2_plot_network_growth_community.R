library(sf)
library(tidyverse)
library(ggtext)
library(tmap)

graph_sf <- readRDS(paste0("../data/", chosen_city, "/graph_with_flows_weighted_communities.RDS"))

# we weigh the flow on each edge by its distance. We can then get how much of the commuter km are satisfied
graph_sf$person_km <- graph_sf$flow * graph_sf$d


# get percentage contribution of each edge to the network (distance, flow, person_km)
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



# ----------------------------------- ALGORITHM 2: EGALITARIAN GROWTH ----------------------------------------- #

###########################################################################################################  
### THIS FUNCTION IS ALMOST IDENTICAL TO FUNCTION 5 WITH ONE EXCEPTION. WE START WITH ALL EDGES THAT ALREADY ##
### HAVE CYCLING INFRASTRUCTURE. THESE ARE THE BEGINNING OF THE SOLUTION. TO ENSURE THAT THERE IS AT LEAST ##
### ONE EDGE FROM EACH COMMUNITY, WE GET THE EDGE WITH THE HIGHEST FLOW IN EACH COMMUNITY AND APPEND IT TO ##
### THE SOLUTION AT SEQUENCE 0. 
###########################################################################################################  
                              #########################################
# growth_egal function starts with all edges that already have cycling infrastructure. It may be more 
# practical in real life. It also shows the no of components and the size of the gcc at each iteration
                              #########################################

# let's grow the network based on the flow column
grow_egal <- growth_egalitarian(graph = graph_sf, km = no_cycle_infra, col_name = "flow")

# save
saveRDS(grow_egal, file = paste0("../data/", chosen_city, "/growth_egal.Rds"))
# read in 
#grow_egal <- readRDS(paste0("../data/", chosen_city,"/growth_egal.Rds"))

# get % of edges in gcc
grow_egal$gcc_size_perc <- (grow_egal$gcc_size / nrow(graph_sf)) * 100
# prepare a dataframe for ggplot
grow_egal_c <- grow_egal %>% 
  arrange(sequen) %>%  # make sure it is arranged by sequen (Otherwise cumulative sum values will be wrong)
  ungroup %>%   # not sure why it is a grouped df. This only has an effect on the select argument
  filter(cycle_infra == 0) %>% # all edges with cycle infrastructure were added at the beginning
  #st_drop_geometry() %>% 
  dplyr::select(Community, d, flow, highway, cycle_infra, sequen, perc_dist, perc_flow,
                perc_person_km, perc_dist_comm, perc_flow_comm, perc_person_km_comm, no_components,
                gcc_size, gcc_size_perc)


# We have filtered the dataframe to include only segments without cycling infrastructure. This is because we want 
# to see the effect of adding these segments on the person_km satisfied. However, the initial person_km satisfied is not 0
# but equal to that satisfied by existing infrastructure. We calculate those initial values and add them to the cumulative
# percentages calculated

# get the person_km satisfied by existing infrastructure
initial_perc_satisfied_all <- grow_egal %>%
  ungroup %>%   # otherwise it will get one value per community. Not sure why it is grouped 
  st_drop_geometry() %>% 
  filter(cycle_infra == 1) %>% 
  summarize(sum(perc_person_km)) %>% as.numeric()
# same as above but for each community
initial_perc_satisfied_comm <- grow_egal %>% 
  st_drop_geometry() %>% 
  group_by(Community) %>%
  filter(cycle_infra == 1) %>% 
  summarize(initial_perc_satisfied = sum(perc_person_km_comm)) 

# join the community values so that we can add them to cumsum so that % satisfied does not start at 0 
grow_egal_c <- grow_egal_c %>%
  dplyr::left_join(initial_perc_satisfied_comm, by = c("Community"))

# cumsum is cumulative sum. We see how much of person_km has been satisfied after each iteration 
grow_egal_c <- grow_egal_c %>%
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
grow_egal_c$distance_groups <- cut(grow_egal_c$dist_c, breaks = seq(from = 0, to = max(grow_egal_c$dist_c) + 100, by = 100))


# network level plot
ggplot(data=grow_egal_c , aes(x=dist_c, y=perc_person_km_c)) +
  geom_line() +
  ggtitle("Connected Growth from Existing Cycling Infrastructure - *Equal Investment Between Communities*") +
  labs(x = "Length of Investment (km)", y = "% of person km satisfied",
       subtitle=expression("Segments Prioritized Based On **Flow**")) +
  theme_minimal() +
  theme(plot.title = element_markdown(size = 14)) +
  theme(plot.subtitle = element_markdown(size = 10)) +
  #scale_x_continuous(expand = c(0, 0), limits = c(0, NA)) + 
  scale_y_continuous(expand = c(0, 0), limits = c(0, 100))

ggsave(paste0("../data/", chosen_city,"/Plots/Growth_Results/growth_egalitarian_satisfied_km_all_flow_column.png"))

# community level plots
ggplot(data=grow_egal_c, 
       aes(x=dist_c, y=perc_person_km_comm_c, group=Community, color = Community)) +
  geom_line() + 
  ggtitle("Connected Growth from Existing Cycling Infrastructure - *Equal Investment Between Communities*") +
  labs(x = "Total Length of Investment (km)", y = "% of person km satisfied within community",
       subtitle="Segments Prioritized Based On **Flow**") +
  theme_minimal() +
  theme(plot.title = element_markdown(size = 14)) +
  theme(plot.subtitle = element_markdown(size = 10)) +
  scale_x_continuous(expand = c(0, 0), limits = c(0, NA)) + 
  scale_y_continuous(expand = c(0, 0), limits = c(0, 100))

ggsave(paste0("../data/", chosen_city,"/Plots/Growth_Results/growth_egalitarian_satisfied_km_community_flow_column.png"))



# network level plot showing no of components (decreasing?) as network grows
ggplot(data=grow_egal_c , aes(x=dist_c, y=no_components)) +
  geom_line() +
  ggtitle("Number of Components Making Up Network") +
  labs(x = "Length of Investment (km)", y = "No. of Components",
       title = chosen_city, 
       subtitle= paste0("Length of Road Segments with Routed Flow and No Dedicated Infrastructure = ", no_cycle_infra+5, "km")) +
  theme_minimal() +
  theme(plot.subtitle = element_markdown(size =8))

ggsave(paste0("../data/", chosen_city,"/Plots/Growth_Results/growth_egalitarian_components_number_flow_", chosen_city, ".png"))


# network level plot showing size of gcc 
ggplot(data=grow_egal_c , aes(x=dist_c, y=gcc_size_perc)) +
  geom_line() +
  ggtitle(chosen_city) +
  labs(x = "Length of Investment (km)", y = "% of Edges in LCC",
       subtitle="Edges in Largest Connected Component (LCC)") +
  theme_minimal() +
  theme(plot.subtitle = element_markdown())

ggsave(paste0("../data/", chosen_city,"/Plots/Growth_Results/growth_egalitarian_components_gcc_flow_", chosen_city, ".png"))


# Plot how many kms of investment are needed on each highway type. Use the distance_group categorical variable 
# to show how the investment on each highway type is split
grow_egal_c %>% st_drop_geometry() %>% 
  group_by(highway, distance_groups) %>%
  summarize(dist = sum(d) /1000) %>%
  mutate(dist_perc = dist / sum(dist) * 100) %>%  
  dplyr::filter(!(highway %in% c('trunk_link', 'track', 'tertiary_link', 'steps', 
                                 'secondary_link', 'primary_link', 'living_street', 
                                 'motorway_link', 'cycleway'))) -> p

# plot of length of investment on each highway type
ggplot(data=p , aes(x=highway, y=dist, fill = distance_groups)) +
  geom_col(position = position_stack(reverse = TRUE)) +
  scale_fill_brewer(palette = "Blues", direction=-1) +
  ggtitle("Investment on Different Highway Types") +
  labs(x = "Highway Type", y = "Length (km)", fill = "Investment Priority \n(km groups)") +
  theme_minimal() +
  # edit angle of text, hjust argument so that text stays below plot AND center plot title
  theme(axis.text.x = element_text(angle=50, hjust=1), plot.title = element_text(hjust = 0.5)) +
  coord_flip()

ggsave(paste0("../data/", chosen_city,"/Plots/Growth_Results/growth_egalitarian_investment_highways_flow.png"))

###### MAP #####

# inverse sequence so that thickest edges are the ones selected first
grow_egal_c$sequen_inv <- max(grow_egal_c$sequen) - grow_egal_c$sequen

# segments that had dedicated cycling infrastructure
initial_infra <- grow_egal %>% filter(cycle_infra == 1)

#### Plot with colour proportional to km (from cumulative distance column) instead of sequence  ####
tm_shape(graph_sf) +
  tm_lines(col = 'gray95') +
tm_shape(initial_infra) +
  tm_lines(col = 'firebrick2',
           lwd = 2) +
tm_shape(grow_egal_c) +
  tm_lines(title.col = "Priority (km)",
           col = 'dist_c',    # could do col='sequen' to 
           lwd = 'sequen_inv',
           scale = 1.8,     #multiply line widths by X
           palette = "-Blues",
           #style = "cont",   # to get a continuous gradient and not breaks
           legend.lwd.show = FALSE) +
  tm_layout(title = "Growing A Network Around Existing \nCycling Infrastructure",        
            title.size = 1.2,
            title.color = "azure4",
            title.position = c("left", "top"),
            inner.margins = c(0.1, 0.1, 0.1, 0.1),    # bottom, left, top, and right margin
            fontfamily = 'Georgia',
            #legend.position = c("right", "bottom"),
            frame = FALSE) +
  tm_scale_bar(color.dark = "gray60") +
  # add legend for the existing cycling infrastructure
  tm_add_legend(type = "line", labels = 'Existing Cycling Infrastructure', col = 'firebrick2', lwd = 2) -> p


tmap_save(tm = p, filename = paste0("../data/", chosen_city,"/Plots/Growth_Results/growth_egalitarian_priority_all_FLOW.png"))


# facet by community
tm_shape(graph_sf) +
  tm_lines(col = 'gray95') +
tm_shape(initial_infra) +
  tm_lines(col = 'firebrick2',
           lwd = 2) +
  tm_facets(by="Community",
            nrow = 1,
            free.coords=FALSE)  +  # so that the maps aren't different sizes 
  tm_shape(grow_egal_c) +
  tm_lines(title.col = "Priority (km)",
           col = 'dist_c',    # could do col='sequen' to 
           lwd = 'sequen_inv',
           scale = 1.2,     #multiply line widths by X
           palette = "-Blues",
           #style = "cont",   # to get a continuous gradient and not breaks
           legend.lwd.show = FALSE) +
  tm_facets(by="Community",
            nrow = 1,
            free.coords=FALSE)  +  # so that the maps aren't different sizes +
  tm_layout(main.title = "Growing A Network Around Existing Cycling Infrastructure",        
            main.title.size = 1.2,
            main.title.color = "azure4",
            main.title.position = c("left", "top"),
            fontfamily = 'Georgia',
            legend.outside.position = c("right", "bottom"),
            frame = FALSE) +
  # add legend for the existing cycling infrastructure
  tm_add_legend(type = "line", labels = 'Existing Cycling Infrastructure', col = 'firebrick2', lwd = 2) -> p

tmap_save(tm = p, filename = paste0("../data/", chosen_city,"/Plots/Growth_Results/growth_egalitarian_facet_FLOW.png"), 
          width=10, height=4)

# lets show where the 1st 100km selected are (to show distribution of resources across communities)
grow_egal_c_100 <- grow_egal_c %>% dplyr::filter(dist_c <= 100)

tm_shape(graph_sf) +
  tm_lines(col = 'gray95') +
tm_shape(initial_infra) +
  tm_lines(col = 'firebrick2',
           lwd = 1.5) +
  tm_facets(by="Community",
            nrow = 1,
            free.coords=FALSE)  +  # so that the maps aren't different sizes 
tm_shape(grow_egal_c_100) +
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
  tm_layout(main.title = "Distribution of Initial 100km of Investment",        
            main.title.size = 1.2,
            main.title.color = "azure4",
            main.title.position = c("left", "top"),
            fontfamily = 'Georgia',
            legend.outside.position = c("right", "bottom"),
            frame = FALSE) +
  # add legend for the existing cycling infrastructure
  tm_add_legend(type = "line", labels = 'Existing Cycling Infrastructure', col = 'firebrick2', lwd = 1.5) -> p


tmap_save(tm = p, filename = paste0("../data/", chosen_city,"/Plots/Growth_Results/growth_egalitarian_facet_FLOW_100.png"), 
          width=10, height=4)



# -------------------------------------- CONNECTIVITY -------------------------------------- #

# Comparing Utilitarin Approach (Algorithm 1 in Script 8.1) to Egalitarian Approach 

# add column with label to each one, so we can bind them and then do a ggplot by color
grow_util_c$Approach <- "Algorithm 1 (Utilitarian)"

grow_egal_c$Approach <- "Algorithm 2 (Egalitarian)"

# add rows
components_util_egal <- rbind(grow_util_c, grow_egal_c)

# plot
ggplot(data=components_util_egal, 
       aes(x=dist_c, y=no_components,  color = str_wrap(Approach, 15))) + #str_wrap to wrap legend text
  geom_line() +
  labs(x = "Length of Investment (km)", y = "No. of Components",
       title = chosen_city,
       #subtitle = chosen_city,
       color = "") +
  theme_minimal() +
  scale_fill_discrete(labels = c("Algorithm 1 (Utilitarian)", "Algorithm 2 (Egalitarian)")) +
  theme(plot.subtitle = element_markdown(size =12),
        legend.key.height=unit(1, "cm")) # spacing out legend keys

ggsave(paste0("../data/", chosen_city,"/Plots/Growth_Results/growth_egalitarian_components_number_comparison", chosen_city, ".png"))


ggplot(data=components_util_egal , 
       aes(x=dist_c, y=gcc_size_perc, color = str_wrap(Approach, 15))) +
  geom_line() +
  ggtitle(chosen_city) +
  labs(x = "Length of Investment (km)", y = "% of Edges in LCC",
       #subtitle= chosen_city,
       color = "") +
  theme_minimal() +
  scale_fill_discrete(labels = c("Algorithm 1 (Utilitarian)", "Algorithm 2 (Egalitarian)")) +
  theme(plot.subtitle = element_markdown(size = 12),
        legend.key.height=unit(1, "cm")) # spacing out legend keys)

ggsave(paste0("../data/", chosen_city,"/Plots/Growth_Results/growth_egalitarian_components_gcc_comparison", chosen_city, ".png"))


# clear environment 
rm(grow_egal, grow_egal_c, grow_egal_c_100, initial_perc_satisfied_all, initial_perc_satisfied_comm, 
   initial_infra, grow_util_c)
