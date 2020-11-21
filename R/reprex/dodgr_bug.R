library(dodgr)
packageVersion("dodgr")
library(dplyr)

#sf format 
hampi <- dodgr_streetnet("hampi india")
hampi_weighted<- weight_streetnet(hampi, wt_profile = "bicycle") 
# check...all good
head(hampi_weighted) 

#sc format
hampi_sc <- dodgr_streetnet_sc("hampi india")
hampi_sc_weighted <- weight_streetnet(hampi_sc, wt_profile = "bicycle") 


remotes::install_github("hypertidy/geodist") 
remotes::install_github("atfutures/dodgr")
