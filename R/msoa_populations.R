library(tidyverse)

# msoa level population data
msoa_pop <- read_csv("data-raw/mid-2018-msoa-pop.csv", skip = 4)
# some rows have county totals. We remove these
msoa_pop <- msoa_pop %>%
  filter(is.na(`LA (2019 boundaries)`)) %>%
  filter(!(is.na(MSOA)))
  


msoa_pop %>% summarize(mean_pop = mean(`All Ages`))
