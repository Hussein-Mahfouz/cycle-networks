library(tidyverse)
library(stplanr)
library(pct)

# read in the data
flow <- readr::read_csv(paste0("data/",chosen_city,"/flows_dist_elev_for_potential_flow.csv"))
# replace NA values with the mean slope
flow$slope[is.na(flow$slope)] <- mean(na.omit(flow$slope))

###############
# OPTION 1: Use a distance decay function from pct package https://itsleeds.github.io/pct/reference/uptake_pct_godutch.html
###############

# create a copy of the df 
uptake_pct <- flow

# get % increase in cycling as distance decay 
uptake_pct$uptake_dutch = pct::uptake_pct_godutch(distance = uptake_pct$dist, gradient = uptake_pct$slope)

# ggplot(uptake_pct) +
#   geom_point(aes(dist, uptake_dutch)) + 
#   labs( x="Commuting Distance (km)", y = "Uptake (%)")

# get potential demand: non-active flow*uptake + active flow
uptake_pct <- uptake_pct %>% 
  # get current active travel
  mutate(active_travel = Bicycle + `On foot`) %>% 
  # get potential active travel: non-active modes * distance decay parameter
  mutate(potential_demand = round((`All categories: Method of travel to work` - active_travel) * uptake_dutch) + active_travel) 

# save csv to use in '4_aggregating_flows'
uptake_pct %>% 
  subset(select = c(`Area of residence`, `Area of workplace`, `potential_demand`)) %>%
  write_csv(path = paste0("data/",chosen_city, "/flows_for_aggregated_routing_opt_1.csv"))

# all number should be above 0. Cycling should not be more than toal trips...
uptake_pct$increase = uptake_pct$`All categories: Method of travel to work` - uptake_pct$potential_demand

# remove
rm(uptake_pct)
###############

###############
# OPTION 2: without distance decay
###############

# function that takes the following arguments
# 1. dataframe to be used
# 2. max_dist: cutoff distance in meters. All OD pairs above this distance are assumed to have 0 potential demand
# 3. public: fraction of public transport flow that should be considered potential cycling demand
# 4. private: fraction of private vehicle flow that should be considered potential cycling demand
# 3 & 4 are 0 if distance between MSOA pair > max_dist
# 3 & 4 are added to current bicycle trips to create a potential demand column
# Walking is not added to potential demand

potential_demand <- function(data, max_dist = 6000, public = 0.2, private = 0.5) {
   name <- data %>%
     mutate(active = Bicycle + `On foot`) %>%
     mutate(sustainable = (`Underground, metro, light rail, tram` + Train + `Bus, minibus or coach`)) %>%
     mutate(motor = (`All categories: Method of travel to work` - (sustainable + active))) %>%
     mutate(potential_demand = if_else(dist <= max_dist, round(Bicycle + sustainable*public + motor*private), Bicycle))
    return(name)
 }

# use function to get potential demand
uptake_cutoff <- potential_demand(data=flow)
# save as csv
uptake_cutoff %>% 
  subset(select = c(`Area of residence`, `Area of workplace`, `potential_demand`)) %>%
  write_csv(path = paste0("data/",chosen_city, "/flows_for_aggregated_routing_opt_2.csv"))

rm(uptake_cutoff)
###############



###############
# OPTION 3: my own distance decay function
###############

uptake_decay <- flow

# What to do with dist= NA
#1. Remove these rows

uptake_decay <- uptake_decay %>% filter(!is.na(dist))

# 2.replace NA values by column mean 
#uptake_decay$dist[is.na(uptake_decay$dist)] <- max(uptake_decay$dist[!is.na(uptake_decay$dist)])


# get % of cyclists
uptake_decay$perc_cycle <- uptake_decay$Bicycle / uptake_decay$`All categories: Method of travel to work`
# use this df for glm, as intra flows are all assigned distance 0 and so affect the results
uptake_no_intra <- uptake_decay %>% dplyr::filter(`Area of residence` != `Area of workplace`)


# LOGIT
#glm1 <- glm(perc_cycle ~ dist + slope, data = uptake_no_intra, family = "quasibinomial")
#glm1 <- glm(perc_cycle ~ dist + slope, data = uptake_decay, family = "quasibinomial")
# sqrt to get bell shape!  https://itsleeds.github.io/pct/reference/uptake_pct_govtarget.html
# Should I add all_travel as a predictor???
glm1 <- glm(perc_cycle ~ dist + sqrt(dist) + slope, data = uptake_no_intra, family = "quasibinomial")
# add destination zone as proxy for employment/population of MSOA
# glm2 <- glm(perc_cycle ~ dist + sqrt(dist) + slope + `Area of workplace`,
#             data = uptake_no_intra, family = "quasibinomial")

# If coefficient (logit) is positive, the effect of this predictor on cycling is positive and vice versa
#coeff <- coef(glm1) %>% as.data.frame() 
summary(glm1)
#summary(glm2)
# predict cycling probability on all OD pairs
uptake_decay$prob_cycle <- predict(glm1, data.frame(dist = uptake_decay$dist, slope = uptake_decay$slope), type = "response")
# uptake_decay$prob_cycle <- predict(glm2, data.frame(dist = uptake_decay$dist, slope = uptake_decay$slope,
#                                                     `Area of workplace` = uptake_decay$`Area of workplace`), 
#                                    type = "response")

# get goodness of fit
rsq  <- function(observed,estimated){
  r <- cor(observed,estimated)
  R2 <- r^2
  R2
}
rsq(uptake_decay$perc_cycle,uptake_decay$prob_cycle)
#rsq(uptake_no_intra$perc_cycle, uptake_no_intra$prob_cycle)


## DISTRIBUTE ADDITIONAL FLOWS ##

# what is the current proportion of cyclists
cycle_current <- sum(uptake_decay$Bicycle) / sum(uptake_decay$`All categories: Method of travel to work`)
# Let's assume we want cycling mode share to increase by 10%
cycle_target <- cycle_current + 0.1
# no. of additional cycling trips needed to acheive target
cycle_add <- round((cycle_target * sum(uptake_decay$`All categories: Method of travel to work`)) - sum(uptake_decay$Bicycle))

####### 3a. FOR OPTION 1 - START #######
# this column is the pool out of which some fraction will be converted to cyclists
uptake_decay$non_active <- uptake_decay$`All categories: Method of travel to work` - (uptake_decay$Bicycle + uptake_decay$`On foot`)

# this would be the additional number of cyclists if we did not have a target to calibrate to
# it is basically the probability from the glm * non_active commuters
uptake_decay$cycle_added_unweighted <- uptake_decay$prob_cycle * uptake_decay$non_active

# But we need to adjust these values so that the additional cyclists = cycle_add
# We solve for X (multiply_factor):
# the idea is that cycle_added_unweighted(1)*X + cycle_added_unweighted(2) *X ..... = Additional Cycling Trips (cycle_add)
multiply_factor <- cycle_add / sum(uptake_decay$cycle_added_unweighted)
# Get the additional number of trips for each OD pair using multiplication factor found above
uptake_decay$cycling_increase <- (uptake_decay$cycle_added_unweighted) * multiply_factor
# Add additional trips to current trips to get future demand
uptake_decay$potential_demand <- round(uptake_decay$cycling_increase) + uptake_decay$Bicycle

# lets see if any of the potential demand values are above the total flow
uptake_decay$cycle_fraction = uptake_decay$potential_demand / uptake_decay$`All categories: Method of travel to work`
# Ideally, all values should be between 0 and 1
max(uptake_decay$cycle_fraction) 
min(uptake_decay$cycle_fraction) 

# mode share of potential_deand column should = cycle_target
sum(uptake_decay$potential_demand) / sum(uptake_decay$`All categories: Method of travel to work`)

#save csv for routing
uptake_decay %>% 
  subset(select = c(`Area of residence`, `Area of workplace`, `potential_demand`)) %>%
  write_csv(path = paste0("data/",chosen_city, "/flows_for_aggregated_routing_opt_3.csv"))

#save csv for plotting desire_lines (script: _3.2_plot_od_comparisons)
uptake_decay %>%
  write_csv(path = paste0("data/",chosen_city, "/flows_for_desire_lines.csv"))

rm(cycle_add, cycle_current, multiply_factor, uptake_decay, uptake_no_intra, glm1,
   rsq, potential_demand, flow)






       