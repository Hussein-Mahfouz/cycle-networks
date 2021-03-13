# Aim: reproduce results for other UK cities

chosen_city <- "Leeds"

source("R/_1.0_get_flow_data.R")

# Get open data needed for 2nd script. Warning: 100 MB file
piggyback::pb_download("MSOA_2011_Boundaries.zip", tag = "1")
unzip("MSOA_2011_Boundaries.zip", exdir = "data-raw")

# file.edit("R/_2.0_distance_and_elevation.R")
source("R/_2.0_distance_and_elevation.R")

# file.edit("R/_3.0_potential_demand.R")
source("R/_3.0_potential_demand.R")
# check if figures have been created
magick::image_read("data/Leeds/Plots/mode_share_increase_vs_performance_smooth_Leeds.png")

remotes::install_cran("waffle")
remotes::install_cran("latex2exp")

source("R/_3.1_plot_mode_shares.R")
source("R/_3.2_plot_od_comparison.R")
source("R/_3.3_plot_desire_lines_current_vs_potential.R")


source("R/_4.0_aggregating_flows.R")

file.exists("data/Leeds/msoa_lon_lat.shp")
file.exists("data/Leeds/graph_with_flows_unweighted.Rds")
# file.edit("R/_5.0_identifying_cycle_infastructure_from_osm_tags.R")
# Warning: takes several minutes to run
source("R/_5.0_identifying_cycle_infastructure_from_osm_tags.R")

# file.edit("R/_6.0_comparing_weighting_profiles.R")
source("R/_6.0_comparing_weighting_profiles.R")

file.edit("R/_7.0_community_detection.R")
source("R/_7.0_community_detection.R")

source("R/_8.0_growing_a_network.R")
source("R/_8.1_growth_utilitarian.R")
source("R/_8.2_growth_egalitarian.R")

source("R/_")


source("R/_3.1_plot_mode_shares.R")


