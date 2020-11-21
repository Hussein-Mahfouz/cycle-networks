library(tidyverse)
library(waffle)

# read in the data
flow <- readr::read_csv(paste0("data/",chosen_city,"/flows_for_desire_lines.csv"))

#######################
# PLOTTING MODE SHARE
#######################

# prepare data for mode share pie chart
flow_pie <- flow %>% 
  dplyr::select("All categories: Method of travel to work", "Work mainly at or from home",
                       "Underground, metro, light rail, tram", "Train", "Bus, minibus or coach", "Taxi", 
                       "Motorcycle, scooter or moped", "Driving a car or van", "Passenger in a car or van", "Bicycle",
                       "On foot", "Other method of travel to work") %>% 
  summarize_if(is.numeric, sum, na.rm=TRUE)    # get column sums

# change to dataframe with key: value. Do some summaries and name changes 
flow_pie <- flow_pie %>% 
  mutate(`Public Transport` = `Underground, metro, light rail, tram` + Train + `Bus, minibus or coach`,
          Car = `Driving a car or van` + `Passenger in a car or van`,
          Other = `All categories: Method of travel to work` - (`Public Transport` + Car + Bicycle + `On foot`)) %>%
  dplyr::select(`Public Transport`, Car, Bicycle, `On foot`, Other) %>%
  t() %>%  # transpose to turn row into column
  as.data.frame()  %>% # convert from matrix to dataframe
  rownames_to_column() %>%   # turn rownames to first column
  rename(value = V1, mode = rowname)

ggplot(flow_pie, aes(x="", y=value, fill=mode)) +
  geom_bar(stat="identity", width=1, color="white") +
  coord_polar("y", start=0) +
  theme_void() # remove background, grid, numeric labels

ggsave(paste0("data/", chosen_city,"/Plots/mode_share_pie.png"))


# waffle chat
flow_waffle <- flow_pie
# change values to % so that we have 100 boxes in the waffle chart
flow_waffle$value <- (flow_waffle$value / sum(flow_waffle$value)) * 100  
# plot
waffle(parts = flow_waffle$value , rows = 6, title = paste0("Mode Share - ", chosen_city), 
       legend_pos = "bottom")  

ggsave(paste0("data/", chosen_city,"/Plots/mode_share_waffle.png"))

# ggplot(flow_waffle, aes(fill = mode, values = value)) +
#   geom_waffle(color = "white", n_rows = 6) +
#   scale_color_brewer(palette="Blues") +
#   theme(panel.grid = element_blank(), axis.text = element_blank(), axis.ticks = element_blank(), panel.background = element_blank()) 

##############
# PLOTTING DISTANCE VS FLOW
##############

#plot distance vs flow
# remove intra flows
flow_plot <- flow %>% dplyr::filter(`Area of residence` != `Area of workplace`)

# all motorized trips
flow_plot$motor <- flow_plot$`Underground, metro, light rail, tram` + flow_plot$Train +
  flow_plot$`Bus, minibus or coach` + flow_plot$Taxi + flow_plot$`Motorcycle, scooter or moped` + 
  flow_plot$`Driving a car or van` + flow_plot$`Passenger in a car or van`

# all non_motorized trips
flow_plot$active <- flow_plot$Bicycle + flow_plot$`On foot` 

# all trips by public transport or acyive modes
flow_plot$sustainable <- flow_plot$active + flow_plot$`Underground, metro, light rail, tram` + 
  flow_plot$Train + flow_plot$`Bus, minibus or coach` 

# all trips by private vehicles
flow_plot$private <- flow_plot$Taxi + flow_plot$`Motorcycle, scooter or moped` + 
  flow_plot$`Driving a car or van` + flow_plot$`Passenger in a car or van` 

# subset for histograms
flow_plot <- flow_plot %>% dplyr::select(`Area of residence`, `Area of workplace`, 
                                         `All categories: Method of travel to work`, 
                                         Bicycle, motor, active, sustainable, private, dist, 
                                         potential_demand)

# repeat each row based on the value for 'All Categories...' for histogram
flow_long_all <- flow_plot %>% tidyr::uncount(`All categories: Method of travel to work`) %>%
  dplyr::select(`Area of residence`, `Area of workplace`, dist)
# convert from m to km
flow_long_all$dist <- flow_long_all$dist / 1000

ggplot(flow_long_all, aes(x = dist)) + 
  geom_histogram(color = "black", alpha = 0.5, binwidth = 0.5) +
  labs(title = "Trips Made By All Modes", x="Commuting Distance (km)", y = "No. of trips")


# repeat each row based on the value in Bicycle (for histogram!)
flow_long_bike <- flow_plot %>% tidyr::uncount(Bicycle) %>%
  dplyr::select(`Area of residence`, `Area of workplace`, dist)
# convert from m to km
flow_long_bike$dist <- flow_long_bike$dist / 1000

ggplot(flow_long_bike, aes(x = dist)) + 
  geom_histogram(color = "black", alpha = 0.4, binwidth = 1) +
  theme_minimal() +
  labs(title = "Trips Made By Bicycle", x="Commuting Distance (km)", y = "No. of Commuters")

ggsave(paste0("data/", chosen_city,"/Plots/histogram_distance_cycling.png"))

###
flow_long_motor <- flow_plot %>% tidyr::uncount(motor) %>%
  dplyr::select(`Area of residence`, `Area of workplace`, dist)

# convert from m to km
flow_long_motor$dist <- flow_long_motor$dist / 1000

ggplot(flow_long_motor, aes(x = dist)) + 
  geom_histogram(color = "black", alpha = 0.5) +
  labs(title = "All Motorized Trips", x="Commuting Distance (km)", y = "No. of trips")

### 
flow_long_active <- flow_plot %>% tidyr::uncount(active) %>%
  dplyr::select(`Area of residence`, `Area of workplace`, dist)

# convert from m to km
flow_long_active$dist <- flow_long_active$dist / 1000

ggplot(flow_long_active, aes(x = dist)) + 
  geom_histogram(color = "black", alpha = 0.5) +
  labs(title = "Active Trips", x="Commuting Distance (km)", y = "No. of trips")

### 
flow_long_sustainable <- flow_plot %>% tidyr::uncount(sustainable) %>%
  dplyr::select(`Area of residence`, `Area of workplace`, dist)

# convert from m to km
flow_long_sustainable$dist <- flow_long_sustainable$dist / 1000

ggplot(flow_long_sustainable, aes(x = dist)) + 
  geom_histogram(color = "black", alpha = 0.5) +
  labs(title = "Trips Made by Sustainable Modes", 
       x="Commuting Distance (km)", y = "No. of trips")

### 
flow_long_private <- flow_plot %>% tidyr::uncount(private) %>%
  dplyr::select(`Area of residence`, `Area of workplace`, dist)

# convert from m to km
flow_long_private$dist <- flow_long_private$dist / 1000

ggplot(flow_long_private, aes(x = dist)) + 
  geom_histogram(color = "black", alpha = 0.5) +
  labs(title = "Trips Made by Private Vehicles", 
       x="Commuting Distance (km)", y = "No. of trips")


### POTENTIAL DEMAND - CALCULATED FROM SCRIPT 3

# repeat each row based on the value for 'potential demand' for histogram
flow_long_potential <- flow_plot %>% tidyr::uncount(potential_demand) %>%
  dplyr::select(`Area of residence`, `Area of workplace`, dist)
# convert from m to km
flow_long_potential$dist <- flow_long_potential$dist / 1000

ggplot(flow_long_potential, aes(x = dist)) + 
  geom_histogram(color = "black", alpha = 0.5) +
  labs(title = "Potential Cycling Demand", x="Commuting Distance (km)", y = "No. of trips")

                             ######################################
############### Plot histograms overlaying bicycle distribtion on total flow distribution ###############
                             ######################################
histogram<- rbind(flow_long_all, flow_long_bike, flow_long_potential)

### current cycling trips vs all commuter trips
cols <- c("All" = "grey60", "Bicycle (Current)" = "darkred")
ggplot(histogram, aes(x=dist)) + 
  geom_histogram(data=flow_long_all, color = 'grey50', aes(fill = "All")) +
  geom_histogram(data= flow_long_bike, color = 'grey50', aes(fill = "Bicycle (Current)")) +
  scale_fill_manual(name = "Mode", values = cols) +
  labs(title = "Current Cycling Trips Compared to All Trips", 
       x="Commuting Distance (km)", y = "No. of Commuters", color = "Legend")

ggsave(paste0("data/", chosen_city,"/Plots/histogram_distance_all_vs_cycling.png"))

### potential cycling trips vs all commuter trips
cols <- c("All" = "grey60", "Bicycle (Potential)" = "darkgreen")
ggplot(histogram, aes(x=dist)) + 
  geom_histogram(data=flow_long_all, color = 'grey50', aes(fill = "All")) +
  geom_histogram(data= flow_long_potential, color = 'grey50', aes(fill = "Bicycle (Potential)")) +
  scale_fill_manual(name = "Mode", values = cols) +
  labs(title = "Potential Cycling Trips Compared to All Trips", 
       x="Commuting Distance (km)", y = "No. of Commuters", color = "Legend") 

ggsave(paste0("data/", chosen_city,"/Plots/histogram_distance_all_vs_cycling_potential.png"))

### current cycling trips vs potential cycling trips
cols <- c("Potential" = "darkgreen", "Current" = "darkred")
ggplot(histogram, aes(x=dist)) + 
  geom_histogram(data=flow_long_potential, color = 'grey50', aes(fill = "Potential")) +
  geom_histogram(data= flow_long_bike, color = 'grey50', aes(fill = "Current")) +
  scale_fill_manual(name = "", values = cols) +
  labs(title = "Current vs Potential Cycling Trips", 
       x="Commuting Distance (km)", y = "No. of Commuters", color = "Legend") 

ggsave(paste0("data/", chosen_city,"/Plots/histogram_distance_cycling_potential_vs_current.png"))



rm(flow, flow_pie, flow_waffle, flow_plot, flow_long_all, flow_long_active, flow_long_bike, flow_long_motor, flow_long_private, 
   flow_long_sustainable, flow_long_potential, histogram, cols)







