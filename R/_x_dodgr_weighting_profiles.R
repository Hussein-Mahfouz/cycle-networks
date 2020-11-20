library(dodgr)
library(tidyverse)

# dodgr weight profiles
weight_profiles <-dodgr::weighting_profiles$weighting_profiles %>% 
  filter(name == 'bicycle')

# default street weights from dodgr
weights <- dodgr::weighting_profiles$weighting_profiles
speeds <- dodgr::weighting_profiles$surface_speeds
penalties <- dodgr::weighting_profiles$penalties

# look at weights for bicycle
weights_bicycle <- dodgr::weighting_profiles$weighting_profiles %>% 
  filter(name == 'bicycle')

write_dodgr_wt_profile(file = "data/weight_profile_default")

