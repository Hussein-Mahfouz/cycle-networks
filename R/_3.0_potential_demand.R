library(tidyverse)
library(stplanr)
library(pct)

# read in the data
flow <- readr::read_csv(paste0("data/",chosen_city,"/flows_dist_elev_for_potential_flow.csv"))
# replace NA values with the mean slope
flow$slope[is.na(flow$slope)] <- mean(na.omit(flow$slope))


# ---------------------------------------------------------------------------------------------------- #

###############
# OPTION 1: Use a distance decay function from pct package https://itsleeds.github.io/pct/reference/uptake_pct_godutch.html
###############

# create a copy of the df 
uptake_decay <- flow

# What to do with dist= NA
#opt 1. Remove these rows
uptake_decay <- uptake_decay %>% filter(!is.na(dist))

# get % of cyclists
uptake_decay$perc_cycle <- uptake_decay$Bicycle / uptake_decay$`All categories: Method of travel to work`

# get % increase in cycling as distance decay 
uptake_decay$prob_cycle = pct::uptake_pct_govtarget_2020(distance = uptake_decay$dist, gradient = uptake_decay$slope)

ggplot(uptake_decay) +
  geom_point(aes(dist, prob_cycle)) + 
  labs( x="Commuting Distance (km)", y = "Uptake (%)")

# see over and under performers (performance < 1 : underperforming, and so has more potential cyclists)
uptake_decay$performance <- uptake_decay$perc_cycle / uptake_decay$prob_cycle

ggplot(uptake_decay, aes(x = performance)) +
  geom_histogram(color = "black", alpha = 0.5, binwidth = 0.25) +
  geom_vline(xintercept = 1, linetype="dotted", size=0.5) +
  labs(x="Existing Cycling Mode Share As a Fraction of Cycling Potential", y = "No. of OD Pairs")


# Calculate POTENTIAL DEMAND
uptake_decay <- uptake_decay %>% 
  # Get the additional number of cycling trips for each OD pair 
  mutate(cycle_added_weighted = round((`All categories: Method of travel to work` - Bicycle) * prob_cycle)) %>% 
  #mutate(cycle_added_weighted2 = round(((`All categories: Method of travel to work` - Bicycle) * prob_cycle) * exp(-(log(2)*performance)))) %>% 
  # add additional trips to existing bicycle trips to get total potential demand
  mutate(potential_demand = cycle_added_weighted + Bicycle)

# # check effect of scaling down with an exponential
# uptake_decay %>% select(performance, cycle_added_weighted, cycle_added_weighted2) %>%
#   pivot_longer(!performance, names_to = "method", values_to = "additional cyclists") %>%
# ggplot(aes(x=performance, y=`additional cyclists`, color = method)) + 
#   geom_smooth()

# lets see if any of the potential demand values are above the total flow
uptake_decay$cycle_fraction = uptake_decay$potential_demand / uptake_decay$`All categories: Method of travel to work`
# Ideally, all values should be between 0 and 1
max(uptake_decay$cycle_fraction)
min(uptake_decay$cycle_fraction)

# current cycling mode share as fraction
cycle_current <- sum(uptake_decay$Bicycle) / sum(uptake_decay$`All categories: Method of travel to work`)
# cycle mode share in the future (after potential demand is calculated)
cycle_target <- sum(uptake_decay$potential_demand) / sum(uptake_decay$`All categories: Method of travel to work`)

# uptake_decay <- mutate(uptake_decay, 
#                        cycle_added_unweighted = (non_active * prob_cycle) * exp(-(log(2)*performance)))
# 

# ---------------------------------------------------------------------------------------------------- #

#########################
###### PLOTS #####
#########################

# CREATE GROUPED COLUMN BY DISTANCE
# change distance from m to km
uptake_decay$dist2 <- uptake_decay$dist / 1000
# group data by distance. Change 'by' to edit number of groups
uptake_decay$distance_groups <- cut(uptake_decay$dist2, breaks = seq(from = 0, to = 50, by = 1))

# edit the distance group column to replace (0,1] with 0-1km
#  \\ used when replacing "(" to avoid error 
# https://stackoverflow.com/questions/9449466/remove-parenthesis-from-a-character-string
uptake_decay <- uptake_decay %>% 
  mutate(distance_groups = gsub("\\(", "", distance_groups)) %>%
  mutate(distance_groups = gsub("]", " km", distance_groups)) %>%
  mutate(distance_groups = gsub(",", "-", distance_groups))


# Group them for better graph (Reduce number of lines from 10 to 5). Use embedded ifelse
uptake_decay$distance_groups_comb <- ifelse(uptake_decay$distance_groups %in% c("0-1 km", "1-2 km"), "0-2 km",
                                            ifelse(uptake_decay$distance_groups %in% c("2-3 km", "3-4 km"), "2-4 km",
                                                   ifelse(uptake_decay$distance_groups %in% c("4-5 km", "5-6 km"), "4-6 km",
                                                          ifelse(uptake_decay$distance_groups %in% c("6-7 km", "7-8 km"), "6-8 km",
                                                                 ifelse(uptake_decay$distance_groups %in% c("8-9 km", "9-10 km"), "8-10 km",
                                                                        uptake_decay$distance_groups)))))

# Mode Share Increase VS Performance (Under/Over) - geom smooth

uptake_decay %>% filter(!(is.na(distance_groups))) %>%
  filter(distance_groups %in% c("0-1 km", "1-2 km", "2-3 km", "3-4 km", "4-5 km", "5-6 km",
                                "6-7 km", "7-8 km", "8-9 km", "9-10 km")) %>%
  ggplot() +
  geom_smooth(aes(x = performance, y = (cycle_added_weighted / `All categories: Method of travel to work`) * 100,
                  color = distance_groups_comb)) +
  theme_minimal() +
  #scale_colour_brewer(palette = "Blues") +
  labs(title = "",
       x=expression(paste("Performance (", alpha[ij],")")), y = "Cycling Mode Share Increase (%)",
       color = "Distance Between \nOD Pair (km)")



ggsave(paste0("data/", chosen_city,"/Plots/mode_share_increase_vs_performance_smooth_" , chosen_city, ".png"))




# Mode Share Increase VS Performance (Under/Over) - geom point
uptake_decay %>% filter(!(is.na(distance_groups))) %>%
  filter(distance_groups %in% c("0-1 km", "1-2 km", "2-3 km", "3-4 km", "4-5 km", "5-6 km",
                                "6-7 km", "7-8 km", "8-9 km", "9-10 km")) %>%
  ggplot() +
  geom_jitter(aes(x = performance, y = (cycle_added_weighted / `All categories: Method of travel to work`) * 100,
                  color = distance_groups_comb)) +
  theme_minimal() +
  #scale_colour_brewer(palette = "Blues") +
  labs(title = "",
       x="Existing Cycling Mode Share As Fraction of Cycling Potential", y = "Cycling Mode Share Increase (%)",
       color = "Distance Between \nOD Pair (km)")

ggsave(paste0("data/", chosen_city,"/Plots/mode_share_increase_vs_performance_point_",chosen_city, ".png"))



#save csv for routing
uptake_decay %>% 
  subset(select = c(`Area of residence`, `Area of workplace`, `potential_demand`)) %>%
  write_csv(path = paste0("data/",chosen_city, "/flows_for_aggregated_routing_opt_3.csv"))

#save csv for plotting desire_lines (script: _3.2_plot_od_comparisons)
uptake_decay %>%
  write_csv(path = paste0("data/",chosen_city, "/flows_for_desire_lines.csv"))




# ---------------------------------------------------------------------------------------------------- #


###############
# OPTION 2: my own distance decay function
###############
# uptake_decay <- flow
# 
# # What to do with dist= NA
# #opt 1. Remove these rows
# uptake_decay <- uptake_decay %>% filter(!is.na(dist))
# 
# #opt  2.replace NA values by column mean 
# #uptake_decay$dist[is.na(uptake_decay$dist)] <- max(uptake_decay$dist[!is.na(uptake_decay$dist)])
# 
# # get % of cyclists
# uptake_decay$perc_cycle <- uptake_decay$Bicycle / uptake_decay$`All categories: Method of travel to work`
# # use this df for glm, as intra flows are all assigned distance 0 and so affect the results
# uptake_no_intra <- uptake_decay %>% dplyr::filter(`Area of residence` != `Area of workplace`)
# 
# 
# ##### GLM TO CALCULATE PROBABILITY OF CYCLING BASED ON PHYSICAL GEOGRAPHY (Distance, Slope) #####
# 
# # sqrt to get bell shape!  https://itsleeds.github.io/pct/reference/uptake_pct_govtarget.html
# # Should I add all_travel as a predictor???
# glm1 <- glm(perc_cycle ~ dist + sqrt(dist) + slope, data = uptake_no_intra, family = "quasibinomial")
# 
# # If coefficient (logit) is positive, the effect of this predictor on cycling is positive and vice versa
# #coeff <- coef(glm1) %>% as.data.frame() 
# summary(glm1)
# # predict cycling probability on all OD pairs
# uptake_decay$prob_cycle <- predict(glm1, data.frame(dist = uptake_decay$dist, slope = uptake_decay$slope), type = "response")
# 
# # see over and under performers (performance < 1 : underperforming, and so has more potential cyclists)
# uptake_decay$performance <- uptake_decay$perc_cycle / uptake_decay$prob_cycle
# 
# ggplot(uptake_decay, aes(x = performance)) + 
#   geom_histogram(color = "black", alpha = 0.5, binwidth = 0.25) + 
#   geom_vline(xintercept = 1, linetype="dotted", size=0.5) +
#   labs(x="Existing Cycling Mode Share As a Fraction of Cycling Potential", y = "No. of OD Pairs") 
# 
# ggsave(paste0("data/", chosen_city,"/Plots/histogram_od_pair_performance.png"))
# 
# 
# ##### DISTRIBUTE ADDITIONAL FLOWS #####
# 
# ## 1. Get Current and Target Mode Shares
# 
# # what is the current proportion of cyclists
# cycle_current <- sum(uptake_decay$Bicycle) / sum(uptake_decay$`All categories: Method of travel to work`)
# # Determine a cycling increase % (0.1 = 10%, 0.5 = 50% etc)
# cycle_perc_inc <- 0.1
# # target is cycling mode share corresponding to specified increase
# cycle_target <- cycle_current + cycle_perc_inc
# # no. of additional cycling trips needed to acheive target
# cycle_add <- round((cycle_target * sum(uptake_decay$`All categories: Method of travel to work`)) - sum(uptake_decay$Bicycle))
# 
# ### Add Column Representing Cycling Potential Based on GLM Probabilities
# 
# # this column is the pool out of which some fraction will be converted to cyclists
# uptake_decay$non_active <- uptake_decay$`All categories: Method of travel to work` - (uptake_decay$Bicycle + uptake_decay$`On foot`)
# 
# 
# # additional number of cyclists if we did not have a target to calibrate to:
# 
# # ATTEMPT 2: NEGATIVE EXPONENTIAL
# 
# # We want to scale down the probability of cycling by the current performance level, so we use an exponential
# # [1]. y = ae^-bx    (a is y intercept at x = 0, b is decay rate) ---- choose a = 1
#    # x = performance, y = scaling factor
# # [2]. Get b in terms of a
# #####  NEEDS REVEIWING - START #####
#    # Choose the value of y at x = 1
#    # we can make y = target % increase when x = 1. (so y = 0.1). 
#    # TOr y = 0.5, gives more resonable results. The one above is very biased towards 
#    #####  NEEDS REVEIWING - END #####
#    # At x = 1 -> y = ae^-b  ..... 0.5 = ae^-b
#    # e^-b = 0.5/a
#    # -b = ln(0.5/a) = ln(0.5) - ln(a)
#    # b = ln(a) - ln(0.5) = ln(a/0.5) = ln(2a)      
#    ###### y =  ae^-(ln(2a))x  
# 
# # [3].   Use the exponential to scale down the probabilities based on performance 
#    # scaling factor =   e^-(ln( 2 ))  * performance 
# 
# 
# # uptake_decay <- mutate(uptake_decay, 
# #                        cycle_added_unweighted = (non_active * prob_cycle) * exp(-(log(1/cycle_perc_inc)*performance)))
# 
# 
# uptake_decay <- mutate(uptake_decay, 
#                        cycle_added_unweighted = (non_active * prob_cycle) * exp(-(log(2)*performance)))
# 
# # But we need to adjust these values so that the additional cyclists = cycle_add
# # We solve for X (multiply_factor):
# # the idea is that cycle_added_unweighted(1)*X + cycle_added_unweighted(2) *X ..... = Additional Cycling Trips (cycle_add)
# multiply_factor <- cycle_add / sum(uptake_decay$cycle_added_unweighted)
# # Get the additional number of trips for each OD pair using multiplication factor found above
# uptake_decay$cycle_added_weighted <- (uptake_decay$cycle_added_unweighted) * multiply_factor
# # Add additional trips to current trips to get future demand
# uptake_decay$potential_demand <- round(uptake_decay$cycle_added_weighted) + uptake_decay$Bicycle
# 
# 
# # lets see if any of the potential demand values are above the total flow
# uptake_decay$cycle_fraction = uptake_decay$potential_demand / uptake_decay$`All categories: Method of travel to work`
# # Ideally, all values should be between 0 and 1
# max(uptake_decay$cycle_fraction) 
# min(uptake_decay$cycle_fraction) 
# 
# # mode share of potential_demand column should = cycle_target
# sum(uptake_decay$potential_demand) / sum(uptake_decay$`All categories: Method of travel to work`)


# ---------------------------------------------------------------------------------------------------- #



#########################
###### PLOTS #####
#########################

# # CREATE GROUPED COLUMN BY DISTANCE
# # change distance from m to km
# uptake_decay$dist2 <- uptake_decay$dist / 1000
# # group data by distance. Change 'by' to edit number of groups
# uptake_decay$distance_groups <- cut(uptake_decay$dist2, breaks = seq(from = 0, to = 50, by = 1))
# 
# # edit the distance group column to replace (0,1] with 0-1km
# #  \\ used when replacing "(" to avoid error 
# # https://stackoverflow.com/questions/9449466/remove-parenthesis-from-a-character-string
# uptake_decay <- uptake_decay %>% 
#   mutate(distance_groups = gsub("\\(", "", distance_groups)) %>%
#   mutate(distance_groups = gsub("]", " km", distance_groups)) %>%
#   mutate(distance_groups = gsub(",", "-", distance_groups))
#   
# 
# # Group them for better graph (Reduce number of lines from 10 to 5). Use embedded ifelse
# uptake_decay$distance_groups_comb <- ifelse(uptake_decay$distance_groups %in% c("0-1 km", "1-2 km"), "0-2 km",
#                                        ifelse(uptake_decay$distance_groups %in% c("2-3 km", "3-4 km"), "2-4 km",
#                                          ifelse(uptake_decay$distance_groups %in% c("4-5 km", "5-6 km"), "4-6 km",
#                                            ifelse(uptake_decay$distance_groups %in% c("6-7 km", "7-8 km"), "6-8 km",
#                                              ifelse(uptake_decay$distance_groups %in% c("8-9 km", "9-10 km"), "8-10 km",
#                                                uptake_decay$distance_groups)))))
# 
# 
# # Mode Share Increase VS Performance (Under/Over) - geom smooth
# 
# # uptake_decay %>% filter(!(is.na(distance_groups))) %>%
# #   filter(distance_groups %in% c("0-1 km", "1-2 km", "2-3 km", "3-4 km", "4-5 km", "5-6 km",
# #                                 "6-7 km", "7-8 km", "8-9 km", "9-10 km")) %>% 
# #   ggplot() + 
# #   geom_smooth(aes(x = performance, y = (cycle_added_weighted / `All categories: Method of travel to work`) * 100,
# #                   color = distance_groups_comb)) + 
# #   theme_minimal() +
# #   #scale_colour_brewer(palette = "Set3") +
# #   labs(title = "", 
# #        x="Existing Cycling Mode Share As Fraction of Cycling Potential", y = "Cycling Mode Share Increase (%)", 
# #        color = "Distance \nSeparating \nOD Pair") 
# 
# uptake_decay %>% filter(!(is.na(distance_groups))) %>%
#   filter(distance_groups %in% c("0-1 km", "1-2 km", "2-3 km", "3-4 km", "4-5 km", "5-6 km",
#                                 "6-7 km", "7-8 km", "8-9 km", "9-10 km")) %>% 
#   ggplot() + 
#   geom_smooth(aes(x = performance, y = (cycle_added_weighted / `All categories: Method of travel to work`) * 100,
#                   color = distance_groups_comb)) + 
#   theme_minimal() +
#   #scale_colour_brewer(palette = "Blues") +
#   labs(title = "", 
#        x=expression(paste("Performance (", alpha[ij],")")), y = "Cycling Mode Share Increase (%)", 
#        color = "Distance Between \nOD Pair (km)") 
# 
# # uptake_decay %>% filter(!(is.na(distance_groups))) %>%
# #   filter(distance_groups %in% c("0-1 km", "1-2 km", "2-3 km", "3-4 km", "4-5 km", "5-6 km",
# #                                 "6-7 km", "7-8 km", "8-9 km", "9-10 km")) %>% 
# #   ggplot() + 
# #   geom_smooth(aes(x = performance, y = (cycle_added_weighted / `All categories: Method of travel to work`) * 100,
# #                   color = distance_groups_comb)) + 
# #   theme(text = element_text(size=10)) +
# #   #scale_colour_brewer(palette = "Blues") +
# #   labs(title = "", 
# #        x=TeX("Performance $\\alpha_{ij}$ = Cycling Mode Share $\\phi(c_{ij})$ / Probability of Cycling $P(c_{ij})$"), 
# #        y = "Cycling Mode Share Increase (%)", 
# #        color = "Distance Between \nOD Pair (km)") 
# 
# 
# ggsave(paste0("data/", chosen_city,"/Plots/mode_share_increase_vs_performance_smooth_" , chosen_city, ".png"))
# 
# 
# 
# 
# # Mode Share Increase VS Performance (Under/Over) - geom point
# uptake_decay %>% filter(!(is.na(distance_groups))) %>%
#   filter(distance_groups %in% c("0-1 km", "1-2 km", "2-3 km", "3-4 km", "4-5 km", "5-6 km",
#                                 "6-7 km", "7-8 km", "8-9 km", "9-10 km")) %>% 
#   ggplot() + 
#   geom_jitter(aes(x = performance, y = (cycle_added_weighted / `All categories: Method of travel to work`) * 100,
#                   color = distance_groups_comb)) + 
#   theme_minimal() +
#   #scale_colour_brewer(palette = "Blues") +
#   labs(title = "", 
#        x="Existing Cycling Mode Share As Fraction of Cycling Potential", y = "Cycling Mode Share Increase (%)", 
#        color = "Distance Between \nOD Pair (km)") 
# 
# ggsave(paste0("data/", chosen_city,"/Plots/mode_share_increase_vs_performance_point_",chosen_city, ".png"))
# 
# 
#
# 
# #save csv for routing
# uptake_decay %>% 
#   subset(select = c(`Area of residence`, `Area of workplace`, `potential_demand`)) %>%
#   write_csv(path = paste0("data/",chosen_city, "/flows_for_aggregated_routing_opt_3.csv"))
# 
# #save csv for plotting desire_lines (script: _3.2_plot_od_comparisons)
# uptake_decay %>%
#   write_csv(path = paste0("data/",chosen_city, "/flows_for_desire_lines.csv"))



rm(cycle_add, cycle_current, cycle_perc_inc, multiply_factor, uptake_decay, uptake_no_intra, glm1,
   rsq, potential_demand, flow)






