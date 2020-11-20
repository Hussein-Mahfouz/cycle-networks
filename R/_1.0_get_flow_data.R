library(dplyr)
library(readr)
library(tidyr)
library(ggplot2)
library(ggrepel)

# this is a lookup table matching MSOAs to major towns and cities
city_names <- read_csv('../data-raw/Middle_Layer_Super_Output_Area__2011__to_Major_Towns_and_Cities__December_2015__Lookup_in_England_and_Wales.csv') 
# change column name
city_names <- city_names %>% rename(city = TCITY15NM)

#unique cities
unique(city_names$city)

# number of MSOAs in each city 
no_msoas <- city_names %>% dplyr::group_by(city) %>% dplyr::tally()

##### CHOOSE YOU CITY 
chosen_city <- "Manchester"
#create a directory to store data related to this city (does nothing if directory already exists)
dir.create(paste0("../data/", chosen_city), showWarnings = FALSE)
# create sub-directory to save plots as well
dir.create(paste0("../data/", chosen_city,"/Plots"), showWarnings = FALSE)

##### CHOOSE YOU CITY 

# flow data from the 2011 census https://www.nomisweb.co.uk/census/2011/bulk/rOD1
flows <- read_csv('../data-raw/flow_data.csv')

###############
# MERGING NAMES WITH FLOW DATA (TO GET INTERNAL FLOWS IN ANY CITY)
###############

# add a column with the city name corresponding to each Residence MSOA
flows <- flows %>% left_join(city_names[,c("MSOA11CD", "city")],
                             by = c("Area of residence" = "MSOA11CD")) %>%
  rename(city_origin = city) # rename column so that we know it is referring to the 'Area of residence'

# add a column with the city name corresponding to each Workplace MSOA
flows <- flows %>% left_join(city_names[,c("MSOA11CD", "city")],
                             by = c("Area of workplace" = "MSOA11CD")) %>%
  rename(city_dest = city) # rename column so that we know it is referring to the 'Area of workplace'

# get mode share for all cities - just for report
cycle_mode_share <- flows %>% 
  filter(city_origin == city_dest) %>%   # only internal flows
  group_by(city_origin, city_dest) %>%   
  summarize(mode_share = (sum(Bicycle) / sum(`All categories: Method of travel to work`)) *100,
            all = sum(`All categories: Method of travel to work`)) %>%
  arrange(mode_share)

# plot 
cycle_mode_share %>% #filter(city_origin != 'London') %>%
  ggplot(aes(all, mode_share)) +
  geom_point(aes(alpha = mode_share), show.legend = FALSE) +
  # some filtering labels for aesthetic purposes. Add some cities explicitly as they are in my case study
  geom_label_repel(aes(label = ifelse(mode_share>12 | all> (2.3*mean(all)) | city_origin %in% c('Manchester', 'Nottingham', 'Birmingham') , as.character(city_origin),'')), 
                       size =2.5) +
  labs(x="Total Number of Commuters", y = "Cycling Mode Share (%)") +
  scale_x_continuous(trans='log10', labels = scales::comma) +
  theme_minimal()

ggsave("../data/uk_cities_mode_share.png")

# Subset flows to keep only those that are within a specific city
# function to return rows where origin and destination match the specified city name 


flows_internal <- function(name) {
  x <- flows %>% filter(city_origin == name, city_dest == name)
  return(x)
}

# use function to get flows between all MSOAs in city. Remove pairs with total flow < 10
flows_city <- flows_internal(chosen_city) %>% 
  dplyr::filter(`All categories: Method of travel to work` > 10) 

# save as csv to use in next step
write_csv(flows_city, path = paste0("../data/", chosen_city, "/flows_city.csv"))

# remove variables from global environment
rm(flows, flows_city, flows_internal, cycle_mode_share, no_msoas)

