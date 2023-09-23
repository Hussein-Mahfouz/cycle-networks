library(tidyverse)
library(ggrepel)
library(sf)

# towns and cities dataset 
cities <- read_csv('data-raw/MSOA_2011_to_Major_Towns_and_Cities.csv') 

# census 2021 commuting mode share
census_2021_modes <- read_csv('data-raw/census_2021_method_travel_work.csv', , skip = 6) %>%
  rename(MSOA21CD = mnemonic)
  

# msoa 2011 to msoa 2021
msoa_lookup <- read_csv('data-raw/MSOA_2011_to_MSOA_2021.csv') %>%
  select(MSOA11CD, MSOA21CD)


# match census 2021 data onto 2011 msoa codes
census_2021_modes <- census_2021_modes %>%
  left_join(msoa_lookup, by = "MSOA21CD") %>%
  relocate(MSOA11CD, .after = MSOA21CD)

# total commuters


census_2021_modes <- census_2021_modes %>%
  mutate(total_commuters = rowSums(across(`Underground, metro, light rail, tram`:`Other method of travel to work`))) 
  

# ----- join cities dataset and get cycling % per city 

census_2021_cities <- census_2021_modes %>% 
  left_join(cities, by = "MSOA11CD")

# get cycling mode share
census_2021_cities <- census_2021_cities %>%
  group_by(TCITY15NM) %>%
  summarise(Bicycle = sum(Bicycle), total_commuters = sum(total_commuters)) %>%
  ungroup() %>%
  mutate(cycling_perc = round((Bicycle / total_commuters) * 100, 1))

census_2021_cities <- census_2021_cities %>%
  mutate(manc = ifelse(TCITY15NM == "Manchester", "yes", "no"))

# ----- plot cycling 


census_2021_cities %>% #filter(city_origin != 'London') %>%
  ggplot(aes(total_commuters, cycling_perc)) +
  geom_point(aes(alpha = sqrt(cycling_perc), col = manc, size = total_commuters), show.legend = FALSE) +
  # some filtering labels for aesthetic purposes. Add some cities explicitly as they are in my case study
  geom_label_repel(aes(label = ifelse(cycling_perc> 7.3 | total_commuters> (1.8 *mean(total_commuters, na.rm = TRUE)) | TCITY15NM %in% c('Manchester', 'Nottingham', 'Birmingham') , as.character(TCITY15NM),'')), 
                   size = 4) +
  labs(x="Total Number of Commuters", y = "Cycling Mode Share (%)") +
  scale_x_continuous(trans='log10', labels = scales::comma) +
  scale_color_manual(values = c("yes" = "#D0312D", "no" = "black")) +
  theme_minimal()

ggsave("data/uk_cities_mode_share_2021.png", width = 12, height = 8)

