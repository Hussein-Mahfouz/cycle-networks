library(tidyverse)
library(pct)
library(sf)

        # ------------------  1. GET THE DATA - START ------------------ #

flow <- pct::get_pct(region = "london", layer = "rf")

        # ------------------ 1. GET THE DATA - END  ------------------ #

        # ------------------ 2. PROBABILITY OF CYCLING (GLM) - START ------------------ #

#copy the data to another df and keep only the necessary columns
uptake <- flow %>% 
  st_drop_geometry %>%
  dplyr::select(geo_code1, geo_code2, all, bicycle, foot, rf_dist_km, rf_avslope_perc) %>%
  rename(dist = rf_dist_km, slope = rf_avslope_perc)
# save it for next time
write_csv(uptake, path = "reprex/flows_london_decay.csv")
#uptake <- read_csv("reprex/flows_london_decay.csv")

# get % of cyclists
uptake$perc_cycle <- uptake$bicycle / uptake$all
# use this df for glm, as intra flows are all assigned distance 0 and so affect the results
uptake_no_intra <- uptake %>% dplyr::filter(geo_code1 != geo_code2)

# sqrt to get bell shape!  https://itsleeds.github.io/pct/reference/uptake_pct_govtarget.html
glm1 <- glm(perc_cycle ~ dist + sqrt(dist) + slope, 
            data = uptake_no_intra, family = "quasibinomial")


# If coefficient (logit) is positive, the effect of this predictor on cycling is positive and vice versa
#coeff <- coef(glm1) %>% as.data.frame() 
summary(glm1)
#summary(glm2)

# predict cycling probability on all OD pairs, including those with distance = 0
uptake$prob_cycle <- predict(glm1, data.frame(dist = uptake$dist, slope = uptake$slope), type = "response")

# get goodness of fit
rsq  <- function(observed,estimated){
  r <- cor(observed,estimated)
  R2 <- r^2
  R2
}

rsq(uptake$perc_cycle,uptake$prob_cycle)

# see over and under performers (performance < 1 : underperforming, and so has more potential cyclists)
uptake$performance <- uptake$perc_cycle / uptake$prob_cycle

ggplot(uptake, aes(x = performance)) + 
  geom_histogram(color = "black", alpha = 0.5, binwidth = 0.25) + 
  geom_vline(xintercept = 1, linetype="dotted", size=0.5) +
  labs(x="Existing Cycling Mode Share As a Fraction of Cycling Potential", y = "No. of OD Pairs") 

        # ------------------ 2. PROBABILITY OF CYCLING (GLM) - END ------------------ #


        # ------------------ 3. DISTRIBUTE ADDITIONAL FLOWS - START ------------------ #

# what is the current cycling mode share
cycle_current <- sum(uptake$bicycle) / sum(uptake$all)
#get it as a %
cycle_current*100

# Let's assume we want cycling mode share to increase to 10%
cycle_target <- 0.1
# no. of additional cycling trips needed to acheive target
cycle_add <- round((cycle_target * sum(uptake$all)) - sum(uptake$bicycle))
cycle_add
# this column is the pool out of which some fraction will be converted to cyclists 
# we don't imagine a transition from walking to cycling
uptake$non_active <- uptake$all - (uptake$bicycle + uptake$foot)

# this would be the additional number of cyclists if we did not have a target to calibrate to:

        # ----------------------- NEGATIVE EXPONENTIAL [START]  ----------------------- #

# We want to scale down the probability of cycling by the current performance level, so we use an exponential
# [1]. y = ae^-bx    (a is y intercept at x = 0, b is decay rate) ---- choose a = 1
    # x = performance, y = scaling factor
# [2]. Get b in terms of a
    #####  NEEDS REVEIWING - START #####
    # Choose the value of y at x = 1
    # we can make y = target % increase when x = 1. (so y = 0.1). 
    # Or y = 0.5, gives more resonable results. The one above is very biased towards 
    #####  NEEDS REVEIWING - END #####
    # At x = 1 -> y = ae^-b  ..... 0.5 = ae^-b
    # e^-b = 0.5/a
    # -b = ln(0.5/a) = ln(0.5) - ln(a)
    # b = ln(a) - ln(0.5) = ln(a/0.5) = ln(2a)      
    ###### y =  ae^-(ln(2a))x  

# [3].   Use the exponential to scale down the probabilities based on performance 
# scaling factor =   e^-(ln( 2 ))  * performance 

uptake <- mutate(uptake, 
                       cycle_added_unweighted = (non_active * prob_cycle) * exp(-(log(2)*performance)))

      # ----------------------- NEGATIVE EXPONENTIAL [END]  ----------------------- #

# But we need to adjust these values so that the additional cyclists = cycle_add
# We solve for X (multiply_factor):
# the idea is that cycle_added_unweighted(1)*X + cycle_added_unweighted(2) *X ..... = Additional Cycling Trips (cycle_add)
multiply_factor <- cycle_add / sum(uptake$cycle_added_unweighted)
multiply_factor
# Get the additional number of trips for each OD pair using multiplication factor found above
uptake$cycling_increase <- (uptake$cycle_added_unweighted) * multiply_factor
# Add additional trips to current trips to get future demand
uptake$potential_demand <- round(uptake$cycling_increase) + uptake$bicycle

# lets see if any of the potential demand values are above the total flow
uptake$cycle_fraction = uptake$potential_demand / uptake$all
# Ideally, all values should be between 0 and 1
min(uptake$cycle_fraction) 
max(uptake$cycle_fraction) 

# mode share of potential_demand column should = cycle_target (20%)
sum(uptake$potential_demand) / sum(uptake$all)

        # ------------------ 3. DISTRIBUTE ADDITIONAL FLOWS - END ------------------ #


        # ------------------ 4. VISUALIING RESULTS - START ------------------ #

# UPTAKE VS DISTANCE

# get data in long format for ggplot
uptake %>% 
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
  theme_minimal()


# UPTAKE VS PERFORMANCE

# change distance from m to km
#uptake$dist2 <- uptake$dist / 1000
# group data by distance. Change 'by' to edit number of groups
uptake$distance_groups <- cut(uptake$dist, breaks = seq(from = 0, to = 50, by = 1))

# Mode Share Increase VS Performance (Under/Over) - geom smooth
uptake %>% filter(!(is.na(distance_groups))) %>%
  filter(distance_groups %in% c("(0,1]", "(1,2]", "(2,3]", "(3,4]", "(4,5]", "(5,6]",
                                "(6,7]", "(7,8]", "(8,9]")) %>% 
  ggplot() + 
  geom_smooth(aes(x = performance, y = (cycling_increase / all) * 100,
                  color = distance_groups)) + 
  theme_minimal() +
  scale_colour_brewer(palette = "Blues") +
  labs(title = "", 
       x="Existing Cycling Mode Share As Fraction of Cycling Potential", y = "Cycling Mode Share Increase (%)", 
       color = "Distance Between \nOD Pair (km)") 

# SAME PLOT BUT ZOOMED IN TO PERFORMANCE < 3
# Mode Share Increase VS Performance (Under/Over) -
uptake %>% filter(!(is.na(distance_groups))) %>%
  filter(performance < 3) %>% 
  filter(distance_groups %in% c("(0,1]", "(1,2]", "(2,3]", "(3,4]", "(4,5]", "(5,6]",
                                "(6,7]", "(7,8]", "(8,9]")) %>% 
  ggplot() + 
  geom_smooth(aes(x = performance, y = (cycling_increase / all) * 100,
                  color = distance_groups)) + 
  theme_minimal() +
  scale_colour_brewer(palette = "Blues") +
  labs(title = "", 
       x="Existing Cycling Mode Share As Fraction of Cycling Potential", y = "Cycling Mode Share Increase (%)", 
       color = "Distance Between \nOD Pair (km)") 

        # ------------------ 4. VISUALIING RESULTS - END ------------------ #
