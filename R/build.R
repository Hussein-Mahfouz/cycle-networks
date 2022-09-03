# Aim: reproduce results for other UK cities

chosen_city <- "Manchester"
# chosen_city <- "Bradford" # For a different city

source("R/_1.0_get_flow_data.R")

# # Get open data needed for 2nd script. Warning: 100 MB file  (HM : Uncomment Later)
# piggyback::pb_download("MSOA_2011_Boundaries.zip", tag = "1")
# unzip("MSOA_2011_Boundaries.zip", exdir = "data-raw")

# file.edit("R/_2.0_distance_and_elevation.R")
source("R/_2.0_distance_and_elevation.R")

# file.edit("R/_3.0_potential_demand.R")
source("R/_3.0_potential_demand.R")
# check if figures have been created


source("R/_3.1_plot_mode_shares.R")
source("R/_3.2_plot_od_comparison.R")
source("R/_3.3_plot_desire_lines_current_vs_potential.R")

source("R/_4.0_aggregating_flows.R")

# file.exists("data/Leeds/msoa_lon_lat.shp")
# file.exists("data/Leeds/graph_with_flows_unweighted.Rds")

# Warning: takes several minutes to run
file.edit("R/_5.0_identifying_cycle_infastructure_from_osm_tags.R")
source("R/_5.0_identifying_cycle_infastructure_from_osm_tags.R")

# file.edit("R/_6.0_comparing_weighting_profiles.R")
source("R/_6.0_comparing_weighting_profiles.R")

# file.edit("R/_7.0_community_detection.R")
source("R/_7.0_community_detection.R")

source("R/_8.0_growing_a_network.R")
source("R/_8.1_growth_utilitarian.R")

source("R/_8.2_growth_egalitarian.R")

