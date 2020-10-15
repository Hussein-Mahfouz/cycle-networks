library(tidyverse)
library(pct)
library(sf)

###### 1. GET THE DATA - START ######

#Download the data using the pct package and keep only the necessary columns
flow <- pct::get_pct(region = "london", layer = "rf") %>%
  st_drop_geometry %>%
  select(geo_code1, geo_code2, all, bicycle, rf_dist_km) %>%
  rename(dist = rf_dist_km)

flow_sub <- flow

flow <- pct::get_pct(region = "west-yorkshire", layer = "rf")
###### 1. GET THE DATA - END ######

##### 2. PREDICT CYCLING PROBABILITY - START #####

# get % of cyclists 
#flow_sub$perc_cycle <- flow_sub$bicycle / flow_sub$all

# group rows based on distance column. Change 'by' to edit number of groups
flow_sub$distance_groups <- cut(flow_sub$dist, breaks = seq(from = 0, to = 50, by = 0.5))
#show
flow_sub
# group by distance categories created above and get summary stats
flow_glm <- flow_sub %>%
  group_by(distance_group = as.character(distance_groups)) %>%
  summarise(distance = mean(dist),
            perc_cycle = sum(bicycle)/ sum(all))
#show
flow_glm
# show probabilty of cycling vs distance
ggplot(flow_glm) +
  geom_point(aes(distance, perc_cycle)) + 
  labs( x="Commuting Distance (km)", y = "Probability of Trip Being Cycled")

# model to predict the distance group based on the % of commuters who cycle
### OPTION 1 (part 1): use distance_group as predictor. In this case all rows in the next step 
#                  will have the same prob_cycle 
glm1 <- glm(perc_cycle ~ distance_group, data = flow_glm, family = "quasibinomial")
#OPTION 2 (part 1): use distance as predictor. In this case all rows in the next step 
#                  will have different prob_cycle (because predictor is continuous)
glm2 <- glm(perc_cycle ~ distance, data = flow_glm, family = "quasibinomial")

# predict cycling probability on all OD pairs:

#OPTION 1 (part 2): alll members of same dist_group will have equal probability
flow_sub$prob_cycle <- predict(glm1, data.frame(distance_group = flow_sub$distance_groups), type = "response")

#OPTION 2 (part 2): probability is based on exact distance
flow_sub$prob_cycle2 <- predict(glm2, data.frame(distance= flow_sub$dist), type = "response")

# show the difference. Option 1 is better representation as it is bell shaped
ggplot(flow_sub) +
  geom_point(aes(dist, prob_cycle), color = 'darkred') + 
  geom_point(aes(dist, prob_cycle2), color = 'darkgreen') +
  labs( x="Commuting Distance (km)", y = "Probability of Trip Being Cycled")

#show
flow_sub

##### 2. PREDICT CYCLING PROBABILITY - END #####


##### 3. DISTRIBUTE ADDITIONAL FLOWS - START #####

# what is the current proportion of cyclists
sum(flow_sub$bicycle) / sum(flow_sub$all)
# Let's assume we want cycling mode share to increase to 20%
target_cycle <- 0.2
# no. of additional cycling trips needed to acheive target
target <- round((target_cycle * sum(flow_sub$all)) - sum(flow_sub$bicycle))

####### 3a. FOR OPTION 1 - START #######

# Here we solve for X (multiply_factor):
# the idea is that prob_cycle(1)*X + prob_cycle(2) *X ..... = Target Cycling Trips
multiply_factor <- target / sum(flow_sub$prob_cycle)

# Get the additional number of trips for each OD pair using multiplication factor found above
flow_sub$cycling_increase_20_1 <- flow_sub$prob_cycle * multiply_factor
# Add additional trips to current trips to get future demand
flow_sub$potential_demand_20_1 <- round(flow_sub$cycling_increase_20_1) + flow_sub$bicycle

# lets see if any of the potential demand values are above the total flow
flow_sub$cycle_fraction = flow_sub$potential_demand_20_1 / flow_sub$all
# Ideally, all values should be between 0 and 1
max(flow_sub$cycle_fraction) # NOPE IT IS 1.375!
min(flow_sub$cycle_fraction) # 0.003875969 fine
flow_sub$cycle_fraction[flow_sub$cycle_fraction >= 1]

length(flow_sub$cycle_fraction[flow_sub$cycle_fraction > 1]) #64 rows are above 1

# group to plot Averages
flow_grouped_1 <- flow_sub %>% group_by(distance_groups) %>%
  summarise(distance = mean(dist), 
            perc_cycle = sum(bicycle)/ sum(all),
            perc_cycle_20_1 = sum(potential_demand_20_1)/ sum(all))

# plot to see difference betwwen current demand and future demand
ggplot(flow_grouped_1) +
  geom_point(aes(distance, perc_cycle), color = 'darkred') + 
  #geom_smooth(aes(distance, perc_cycle)) +
  geom_point(aes(distance, perc_cycle_20_1), color = 'darkgreen') +
  #geom_smooth(aes(distance, perc_cycle_20)) +
  labs( x="Commuting Distance (km)", y = "Average Cycling Mode Share (%)")

####### 3a. FOR OPTION 1 - END #######



####### 3b. FOR OPTION 2 - START #######

multiply_factor2 <- target / sum(flow_sub$prob_cycle2)
  
flow_sub$cycling_increase_20_2 <- flow_sub$prob_cycle2 * multiply_factor2  
flow_sub$potential_demand_20_2 <- round(flow_sub$cycling_increase_20_2) + flow_sub$bicycle

# lets see if any of the potential demand values are above the total flow
flow_sub$cycle_fraction2 = flow_sub$potential_demand_20_2 / flow_sub$all
# Ideally, all values should be between 0 and 1
max(flow_sub$cycle_fraction2) # NOPE IT IS 1.3125!
min(flow_sub$cycle_fraction2)
length(flow_sub$cycle_fraction2[flow_sub$cycle_fraction2 > 1]) #64 rows are above 1

# group to plot
flow_grouped_2 <- flow_sub %>% group_by(distance_groups) %>%
  summarise(distance = mean(dist), 
            perc_cycle = sum(bicycle)/ sum(all),
            perc_cycle_20_2 = sum(potential_demand_20_2)/ sum(all))

# plot to see difference betwwen current demand and future demand
ggplot(flow_grouped_2) +
  geom_point(aes(distance, perc_cycle), color = 'darkred') + 
  #geom_smooth(aes(distance, perc_cycle)) +
  geom_point(aes(distance, perc_cycle_20_2), color = 'darkgreen') +
  #geom_smooth(aes(distance, perc_cycle_20_2)) +
  labs( x="Commuting Distance (km)", y = "Average Cycling Mode Share (%)")

####### 3b. FOR OPTION 2 - END #######



##### 4. COMPARE MODE SHARE VS DISTANCE FROM BOTH RESULTS   ######

ggplot(flow_sub) +
  geom_smooth(aes(dist, potential_demand_20_1), color = 'darkred') +
  geom_smooth(aes(dist, potential_demand_20_2), color = 'darkgreen') +
  labs( x="Commuting Distance (km)", y = "Average Cycling Mode Share (%)")


