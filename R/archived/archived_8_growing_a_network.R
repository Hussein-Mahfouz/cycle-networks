library(igraph)
library(sf)
library(sfnetworks)
library(tidyverse)

# graph_sf <- readRDS(paste0("data/", chosen_city, "/graph_with_flows_default_communities.RDS"))


##### FUNCTION TO CHECK IF THE INVESTMENT LENGTH CHOSEN IS REASONABLE. IT SHOULD BE LESS THAN THE TOTAL KM
##### WITHOUT INFRASTRUCTURE

check_km_value <- function(graph, km) {
  ### check if km chosen is a reasonable number. It should be less than the total km without infrastructure
  graph_infra <- graph %>% dplyr::filter(cycle_infra == 1) 
  # total length of edges without cycling infrastructure
  no_cycle <- round((sum(graph$d) - sum(graph_infra$d))  / 1000)
  if( km > no_cycle ){
    stop(paste0("You have chosen to add ", km, "km. There are only ", no_cycle, "km without cycling infrastructure. Please choose a smaller number"))
  }
}

################ FUNCTIONS THAT DON'T DEPEND ON COMMUNITY DETECTION ################

################################################ FUNCTION 1 ################################################
###########################################################################################################  
### THIS FUNCTION IDENTIFIES THE EDGE WITH THE HIGHEST FLOW IN THE WHOLE GRAPH. IT THEN PROCEEDS TO ADD ###
### NEIGHBORING EDGES INCREMENTALLY UNTIL THE INVESTMENT LENGTH IS MET ###
###########################################################################################################  

# 1. select investment length (km)
# 2. Identify edge with highest flow 
# 3. Add edge to solution
# 4. Identify all edges that are connected to the current solution
# 5. Select edge with highest flow and append it to the solution
# 6. Repeat steps 4 & 5 until the length of the edges in the solution reaches the investment length

# col_name: the column that you are choosing segments based on, passed inside "". Could be something other than "flow"
growth_one_seed_OLD <- function(graph, km, col_name) {
  
  ### check if km chosen is a reasonable number (using a predefined function)
  check_km_value(graph, km)
  
  # copy of graph to edit
  x <- graph
  #get edge_id of edge with highest flow
  edge_sel <- x$edge_id[which.max(x[[col_name]])]
  # prepare row for adding to new df
  x <- x %>% filter(edge_id == edge_sel) %>% 
    mutate(sequen= 0)
  # i keeps track of which iteration a chosen edge was added in
  i <- 1
  # j counts km added. We don't count segments that already have cycling infrastructure
  j <- sum(x$d) - sum(x$cycle_infra * x$d)
  
  #while length of chosen segments is less than specified length 
  while (j/1000 < km){
    # remove rows that have already been selected
    remaining <- graph %>% filter(!(edge_id %in% x$edge_id))
    # identify road segments that neighbour existing selection
    neighb_id <- graph$edge_id[which(graph$from_id %in% x$from_id | 
                                       graph$from_id %in% x$to_id |
                                       graph$to_id %in% x$from_id | 
                                       graph$to_id %in% x$to_id)]
    # get neighbouring edges
    neighb <- remaining %>% filter(edge_id %in% neighb_id)
    # get id of best neighboring edge
    edge_sel <- neighb$edge_id[which.max(neighb[[col_name]])]
    # get nest neighboring edge as df row
    edge_next <- graph %>% filter(edge_id == edge_sel) %>% 
      mutate(sequen= i)
    # append it to the solution
    x <- rbind(x, edge_next)
    
    i = i+1
    # Only count length of selected edges that have no cycling infrastructure.
    # if condition is not met, j will not be changed in this iteration
    j = j + (edge_next$d - (edge_next$d * edge_next$cycle_infra))
  }
  return(x)
}



################################################ FUNCTION 2 ################################################
###########################################################################################################  
### THIS FUNCTION IDENTIFIES THE EDGE THAT ALREADY HAVE CYCLING INFRASTRUCTURE. IT THEN PROCEEDS TO ADD ###
### NEIGHBORING EDGES INCREMENTALLY UNTIL THE INVESTMENT LENGTH IS MET ###
###########################################################################################################  
# 1. select investment length (km)
# 2. Identify all edges with cycling infrastructure
# 3. Add these edges to solution
# 4. Identify all edges that are connected to the current solution
# 5. Select edge with highest flow and append it to the solution
# 6. Repeat steps 4 & 5 until the length of the edges in the solution reaches the investment length

growth_existing_infra_OLD <- function(graph, km, col_name) {
  
  ### check if km chosen is a reasonable number (using a predefined function)
  check_km_value(graph, km)
  
  # get all edges with cycling infrastructure - these are the starting point
  x <- graph %>% dplyr::filter(cycle_infra == 1) %>%
    dplyr::mutate(sequen = 0)
  # we need a network representation to get no. of components and size of gcc using igraph
  net <- as_sfnetwork(x)
  # calculate no of components in the solution
  x <- x %>%  mutate(no_components = igraph::count_components(net),
                     # to get size largest connected component 
                     gcc_size = components(net)$csize[which.max(components(net)$csize)])
  # i keeps track of which iteration a chosen edge was added in
  i <- 1
  # j counts km added. We don't count segments that already have cycling infrastructure
  j <- sum(x$d) - sum(x$cycle_infra * x$d)
  
  #while length of chosen segments is less than specified length 
  while (j/1000 < km){
    # remove rows that have already been selected
    remaining <- graph %>% filter(!(edge_id %in% x$edge_id))
    # identify road segments that neighbour existing selection
    neighb_id <- graph$edge_id[which(graph$from_id %in% x$from_id | 
                                       graph$from_id %in% x$to_id |
                                       graph$to_id %in% x$from_id | 
                                       graph$to_id %in% x$to_id)]
    # get neighbouring edges
    neighb <- remaining %>% filter(edge_id %in% neighb_id)
    # get id of best neighboring edge
    edge_sel <- neighb$edge_id[which.max(neighb[[col_name]])]
    # we need a network representation to get no. of components and size of gcc using igraph
    net <- as_sfnetwork(x)
    # get nest neighboring edge as df row
    edge_next <- graph %>% filter(edge_id == edge_sel) %>% 
      mutate(sequen = i,
             # calculate no of components in the solution up to this point
             no_components = igraph::count_components(net),
             # to get size largest connected component 
             gcc_size = components(net)$csize[which.max(components(net)$csize)])
    # append it to the solution
    x <- rbind(x, edge_next)
    
    i = i+1
    # Only count length of selected edges that have no cycling infrastructure.
    j = j + (edge_next$d - (edge_next$d * edge_next$cycle_infra))
  }
  return(x)
}



################ FUNCTIONS THAT UTILIZE COMMUNITY DETECTION ################

################################################ FUNCTION 3 ################################################
###########################################################################################################  
### THIS FUNCTION IDENTIFIES THE EDGE WITH THE HIGHEST FLOW IN EACH COMMUNITY. THESE EDGES ACT AS ###
### SEEDS SO THAT THE GRAPH CAN GROW FROM MULTIPLE LOCATIONS, NOT JUST ONE INITIAL EDGE. WHILE ONE ###
### SEED IS CHOSEN FROM EACH COMMUNITY, THERE IS NO REQUIREMENT FOR THE EDGES APPENDED LATER TO BELONG ###
### TO A SPECIFIC COMMUNITY. WE DO NOT CONTROL FOR THE NUMBER OF EDGES ADDED FROM EACH COMMUNITY. ###
###########################################################################################################  

# 1. select investment length (km)
# 2. Identify edge with highest flow in each community
# 3. Add these edges to solution
# 4. Identify all edges that are connected to the current solution
# 5. Select edge with highest flow and append it to the solution
# 6. Repeat steps 4 & 5 until the length of the edges in the solution reaches the investment length

###############################################################

growth_community_OLD <- function(graph, km, col_name) {
  
  ### check if km chosen is a reasonable number (using a predefined function)
  check_km_value(graph, km)
  
  # copy of graph to edit
  x <- graph
  # Group by community and get the edge with the highest flow in each group
  # to pass column name in function (specific to dplyr): https://stackoverflow.com/questions/480622dplyr-using-column-names-as-function-arguments
  x <-  x %>% group_by(Community) %>% top_n(1, !! sym(col_name)) %>% ungroup()
  # above might return more than one edge per group (edges tied for highest flow), so here we group the 
  # result by Community and select the longer edge
  x <- x %>% group_by(Community) %>% top_n(1, d) %>%
    dplyr::mutate(sequen = 0) %>% ungroup()
  # # alternative method with slice max done twice
  # x <- x %>% group_by(Community) %>%
  #   slice_max(order_by = !! sym(col_name)) %>%
  #   slice_max(order_by = d) %>%
  #   dplyr::mutate(sequen = 0) %>%
  #   ungroup()
  # i keeps track of which iteration a chosen edge was added in
  i <- 1
  # j counts km added. We don't count segments that already have cycling infrastructure
  j <- sum(x$d) - sum(x$cycle_infra * x$d)
  
  #while length of chosen segments is less than specified length 
  while (j/1000 < km){
    # remove rows that have already been selected
    remaining <- graph %>% filter(!(edge_id %in% x$edge_id))
    # identify road segments that neighbour existing selection
    neighb_id <- graph$edge_id[which(graph$from_id %in% x$from_id | 
                                       graph$from_id %in% x$to_id |
                                       graph$to_id %in% x$from_id | 
                                       graph$to_id %in% x$to_id)]
    # get neighbouring edges
    neighb <- remaining %>% filter(edge_id %in% neighb_id)
    # get id of best neighboring edge
    edge_sel <- neighb$edge_id[which.max(neighb[[col_name]])]
    # get nest neighboring edge as df row
    edge_next <- graph %>% filter(edge_id == edge_sel) %>% 
      mutate(sequen = i)
    # append it to the solution
    x <- rbind(x, edge_next)
    
    i = i+1
    # Only count length of selected edges that have no cycling infrastructure.
    # if condition is not met, j will not be changed in this iteration
    
    j = j + (edge_next$d - (edge_next$d * edge_next$cycle_infra))
  }
  return(x)
}



################################################ FUNCTION 4 ################################################
###########################################################################################################  
### THIS FUNCTION ALSO SELECTS A SEED FROM EACH COMMUNITY. IN EACH ITERATION ONE EDGE FROM EACH COMMUNITY ###
### IS CHOSEN. THE CHOSEN EDGE MUST BE CONNECTED TO THE EDGES IN THE COMMUNITY THAT HAVE ALREADY BEEN ###
### CHOSEN. IF THERE ARE NO MORE EDGES IN A PARTICULAR COMMUNITY, THE FUNCTION SKIPS OVER THAT COMMUNITY ###
### AND CONTINUES WITH THE REMAINING COMMUNITIES
###########################################################################################################  

# 1. select investment length (km)
# 2. Identify edge with highest flow in each community
# 3. Add these edges to solution
# 4. For edges in each community
#      i. identify all edges from that community that [a] have not yet been chosen AND [b] neighbor the edges 
#        in the current solution 
#      ii. Select edge from i with highest flow and append it to the solution
# 5. Keep looping over the communities and selecting edges until you reach the investment length
# 6. If there are no neighboring edges remaining for a community, skip it
# 7. If there are no neighboring edges remaining for all communities, break out early and return the solution so
#    far with a message showing the total edges returned (to compare with the input 'km' argument)

###############################################################
growth_community_2_OLD <- function(graph, km, col_name) {
  
  ### check if km chosen is a reasonable number (using a predefined function)
  check_km_value(graph, km)
  
  # copy of graph to edit
  x <- graph
  # Group by community and get the edge with the highest flow in each group ( !! sym(col_name) used to point to col_name variable in function)
  x <- x %>% group_by(Community) %>% top_n(1, !! sym(col_name)) %>% ungroup()
  # above might return more than one edge per group (edges tied for highest flow), so here we group the 
  # result by Community and select the longer edge
  x <- x %>% group_by(Community) %>% top_n(1, d) %>%
    dplyr::mutate(sequen = 0) %>% ungroup()
  ####################
  # split the graph into a list of dataframes with length = number of communities
  split <- graph %>%
    group_split(Community)
  
  # check_conn is a vector of NAs with length = no. of communities. It is used to stop the function if 
  # there are no more connected edges in any of the communities. Otherwise it will go into an infinite loop.
  # We replace the a[i] with the community number if (nrow(neighb) = 0) for that community. If all NAs are replaced
  # we break out
  check_conn <- rep(NA, length(split))
  ####################
  # i keeps track of which iteration a chosen edge was added in
  i <- 1
  # j counts km added. We don't count segments that already have cycling infrastructure
  j <- sum(x$d) - sum(x$cycle_infra * x$d)
  
  #while length of chosen segments is less than the specified length 
  while (j/1000 < km){
    
    # for each community
    for (k in 1:length(split)){
      # edges in community k that have already been chosen 
      chosen    <- split[[k]] %>% filter((edge_id %in% x$edge_id))
      # edges in community k that have not been chosen yet
      remaining <- split[[k]] %>% filter(!(edge_id %in% x$edge_id))
      
      if (nrow(remaining) > 0){
        # all edges that neighbor the edges in the community that have already been chosen
        neighb_id <- split[[k]]$edge_id[which(split[[k]]$from_id %in% chosen$from_id | 
                                                split[[k]]$from_id %in% chosen$to_id |
                                                split[[k]]$to_id %in% chosen$from_id | 
                                                split[[k]]$to_id %in% chosen$to_id)]
        
        # filter out the remaining edges to keep only the ones that neighbor the chosen edges
        neighb <- remaining %>% filter(edge_id %in% neighb_id)
        # it may be the case that the remaining edges in the community are not connected to the chosen edges
        # the edges in each community do not necessarily form one component. If this is the case, then neighb will 
        # return an empty sf feature, so an if function is added to only continue if neighb is not empty
        if (nrow(neighb) > 0){
          #get the edge_id of the edge with the highest flow out of the neighb df
          edge_sel <- neighb$edge_id[which.max(neighb[[col_name]])]
          # get nthe edge from it's edge id, and add a sequen column to show when it was added to the solution
          edge_next <- graph %>% filter(edge_id == edge_sel) %>% 
            mutate(sequen = i)
          # append edge to the solution
          x <- rbind(x, edge_next)
          # Only count length of selected edges that have no cycling infrastructure.
          j = j + (edge_next$d - (edge_next$d * edge_next$cycle_infra))
        } else{
          x <- x
          j <- j
          # add the community number to the check_conn vector
          check_conn[k] <- k
          # if check_conn vector becomes populated with all communities, break out of function
          if (!is.na(sum(check_conn))){
            message(paste0("There are no more connected edges to add for all communities. The returned object has ", round(j/1000),
                           "km out of the specified ", km, "km"))
            return(x)
          }
        }
      } else{
        x <- x
        j <- j
      }
    }
    i <- i+1
  }
  return(x)
}




################################################ FUNCTION 5 ################################################
###########################################################################################################  
### THIS FUNCTION IS ALMOST IDENTICAL TO FUNCTION 4, WITH ONE EXCEPTION. IN FUNCTION 4, IF THERE ARE NO ###
### REMAINING NEIGHBORS IN A COMMUNITY, WE STOP ADDING EDGES FROM THAT COMMUNITY. IN SOME CASES, THE  ###
### EDGES IN A COMMUNITY FORM MORE THAN 1 CONNECTED COMPONENT, SO THERE MAY STILL BE EDGES, EVEN THOUGH ###
### NONE OF THEM ARE CONNECTED TO THE CURRENT SOLUTION. IF THIS IS THE CASE, WE FIND THE BEST (EG. HIGHEST ###
### FLOW) REMAINING UNCONNECTED EDGE IN THE COMMUNITY AND ADD IT TO THE SOLUTION.
###########################################################################################################  

# 1. select investment length (km)
# 2. Identify edge with highest flow in each community
# 3. Add these edges to solution
# 4. For edges in each community
#      - identify edges that neighbor the edges in the solution from that community
#      - Select edge with highest flow and append it to the solution
# 5. Keep looping over the communities and selecting edges until you reach the investment length
# 6. If there are no neighboring edges remaining for a community, check all remaing edges in the community
#    and add the best one, regardless of connectivity

###############################################################


growth_community_3_OLD <- function(graph, km, col_name) {
  
  ### check if km chosen is a reasonable number (using a predefined function)
  check_km_value(graph, km)
  
  # copy of graph to edit
  x <- graph
  # Group by community and get the edge with the highest flow in each group
  x <- x %>% group_by(Community) %>% top_n(1, !! sym(col_name)) %>% ungroup()
  # above might return more than one edge per group (edges tied for highest flow), so here we group the 
  # result by Community and select the longer edge
  x <- x %>% group_by(Community) %>% top_n(1, d) %>%
    dplyr::mutate(sequen = 0) %>% ungroup()
  ####################
  # split the graph into a list of dataframes with length = number of communities
  split <- graph %>%
    group_split(Community)
  
  
  ####################
  # i keeps track of which iteration a chosen edge was added in
  i <- 1
  # j counts km added. We don't count segments that already have cycling infrastructure
  j <- sum(x$d) - sum(x$cycle_infra * x$d)
  
  #while length of chosen segments is less than the specified length 
  while (j/1000 < km){
    
    # for each community
    for (k in 1:length(split)){
      # edges in community k that have already been chosen 
      chosen    <- split[[k]] %>% filter((edge_id %in% x$edge_id))
      # edges in community k that have not been chosen yet
      remaining <- split[[k]] %>% filter(!(edge_id %in% x$edge_id))
      
      if (nrow(remaining) > 0){
        # all edges that neighbor the edges in the community that have already been chosen
        neighb_id <- split[[k]]$edge_id[which(split[[k]]$from_id %in% chosen$from_id | 
                                                split[[k]]$from_id %in% chosen$to_id |
                                                split[[k]]$to_id %in% chosen$from_id | 
                                                split[[k]]$to_id %in% chosen$to_id)]
        
        # filter out the remaining edges to keep only the ones that neighbor the chosen edges
        #### PROBLEM COULD BE HERE
        neighb <- remaining %>% filter(edge_id %in% neighb_id)
        # it may be the case that the remaining edges in the community are not connected to the chosen edges
        # the edges in each community do not necessarily form one component. If this is the case, then neighb will 
        # return an empty sf feature, so an if function is added to only continue if neighb is not empty
        if (nrow(neighb) > 0){
          #get the edge_id of the edge with the highest flow out of the neighb df
          edge_sel <- neighb$edge_id[which.max(neighb[[col_name]])]
          # get nthe edge from it's edge id, and add a sequen column to show when it was added to the solution
          edge_next <- graph %>% filter(edge_id == edge_sel) %>% 
            mutate(sequen = i)
          # append edge to the solution
          x <- rbind(x, edge_next)
          
          j = j + (edge_next$d - (edge_next$d * edge_next$cycle_infra))
        } else{
          #get the edge_id of the edge with the highest flow out of the neighb df
          edge_sel <- remaining$edge_id[which.max(remaining[[col_name]])]
          # get nthe edge from it's edge id, and add a sequen column to show when it was added to the solution
          edge_next <- graph %>% filter(edge_id == edge_sel) %>% 
            mutate(sequen = i)
          # append edge to the solution
          x <- rbind(x, edge_next)
          # Only count length of selected edges that have no cycling infrastructure.
          j = j + (edge_next$d - (edge_next$d * edge_next$cycle_infra))
        }
      } else{
        x <- x
        j <- j
      }
    }
    i <- i+1
  }
  return(x)
}



################################################ FUNCTION 6 ################################################
###########################################################################################################  
### THIS FUNCTION IS ALMOST IDENTICAL TO FUNCTION 5 WITH ONE EXCEPTION. WE START WITH ALL EDGES THAT ALREADY ##
### HAVE CYCLING INFRASTRUCTURE. THESE ARE THE BEGINNING OF THE SOLUTION. TO ENSURE THAT THERE IS AT LEAST ##
### ONE EDGE FROM EACH COMMUNITY, WE GET THE EDGE WITH THE HIGHEST FLOW IN EACH COMMUNITY AND APPEND IT TO ##
### THE SOLUTION AT SEQUENCE 0. 
###########################################################################################################  

# 1. select investment length (km)
# 2. Identify edge with highest flow in each community
# 3. Identify all edges that have designated cycle infrastructure
# 4. Get union of 2 & 3. This ensures that we start with at least one edge from each community
# 4. For edges in each community
#      a. identify edges that neighbour the edges in the solution from that community
#      b. Select edge with highest flow from [a] and append it to the solution
# 5. Keep looping over the communities and selecting edges until you reach the investment length
# 6. If there are no neighboring edges remaining for a community, check all remaing edges in the community
#    and add the best one, regardless of connectivity
# At each iteration we calculate the no of components that make up the current solution. We start with all cycling
# infrastructure and then as edges are added, the number of components should go down

growth_community_4_OLD <- function(graph, km, col_name) {
  
  ### check if km chosen is a reasonable number. Function is defined in the beginning
  check_km_value(graph, km)
  
  # copy of graph to edit
  x <- graph
  # Group by community and get the edge with the highest flow in each group
  x <- x %>% group_by(Community) %>% top_n(1, !! sym(col_name)) %>% ungroup()
  # above might return more than one edge per group (edges tied for highest flow), so here we group the 
  # result by Community and select the longer edge
  x <- x %>% group_by(Community) %>% top_n(1, d) %>%
    dplyr::mutate(sequen = 0) %>% ungroup()
  # get all edges with cycling infrastructure
  y <- graph %>% dplyr::filter(cycle_infra == 1) %>%
    dplyr::mutate(sequen = 0)
  # bind x and y
  x <- rbind(x, y)
  # remove duplicates
  x <- dplyr::distinct(x, edge_id, .keep_all = TRUE) 
  # we need a network representation to get no. of components and size of gcc using igraph
  net <- as_sfnetwork(x)
  # calculate no of components in the solution
  x <- x %>%  mutate(no_components = igraph::count_components(net),
                     # to get size largest connected component 
                     gcc_size = components(net)$csize[which.max(components(net)$csize)])
  
  # split the graph into a list of dataframes with length = number of communities
  split <- graph %>%
    group_split(Community)
  
  # i keeps track of which iteration a chosen edge was added in
  i <- 1
  # j counts km added. We don't count segments that already have cycling infrastructure
  j <- sum(x$d) - sum(x$cycle_infra * x$d)
  
  #while length of chosen segments is less than the specified length 
  while (j/1000 < km){
    
    # for each community
    for (k in 1:length(split)){
      # edges in community k that have already been chosen 
      chosen    <- split[[k]] %>% filter((edge_id %in% x$edge_id))
      # edges in community k that have not been chosen yet
      remaining <- split[[k]] %>% filter(!(edge_id %in% x$edge_id))
      # we need a network representation to get no. of components and size of gcc using igraph
      net <- as_sfnetwork(x)
      # if there are still edges in the community to be selected 
      if (nrow(remaining) > 0){
        # all edges that neighbor the edges in the community that have already been chosen
        neighb_id <- split[[k]]$edge_id[which(split[[k]]$from_id %in% chosen$from_id | 
                                                split[[k]]$from_id %in% chosen$to_id |
                                                split[[k]]$to_id %in% chosen$from_id | 
                                                split[[k]]$to_id %in% chosen$to_id)]
        
        # filter out the remaining edges to keep only the ones that neighbor the chosen edges
        neighb <- remaining %>% filter(edge_id %in% neighb_id)
        # it may be the case that the remaining edges in the community are not connected to the chosen edges
        # the edges in each community do not necessarily form one component. If this is the case, then neighb will 
        # return an empty sf feature, so an if function is added to only continue if neighb is not empty
        if (nrow(neighb) > 0){
          #get the edge_id of the edge with the highest flow out of the neighb df
          edge_sel <- neighb$edge_id[which.max(neighb[[col_name]])]
          # get nthe edge from it's edge id, and add a sequen column to show when it was added to the solution
          edge_next <- graph %>% filter(edge_id == edge_sel) %>% 
            mutate(sequen = i,
                   # calculate no of components in the solution up to this point
                   no_components = igraph::count_components(net),
                   # to get size largest connected component 
                   gcc_size = components(net)$csize[which.max(components(net)$csize)])
          # append edge to the solution
          x <- rbind(x, edge_next)
          
          j <- j + (edge_next$d - (edge_next$d * edge_next$cycle_infra))
        } else{
          #get the edge_id of the edge with the highest flow out of the remaining df
          edge_sel <- remaining$edge_id[which.max(remaining[[col_name]])]
          # get the edge from it's edge id, and add a sequen column to show when it was added to the solution
          edge_next <- graph %>% filter(edge_id == edge_sel) %>% 
            mutate(sequen = i,
                   # calculate no of components in the solution up to this point
                   no_components = igraph::count_components(net),
                   # to get size largest connected component 
                   gcc_size = components(net)$csize[which.max(components(net)$csize)])
          # append edge to the solution
          x <- rbind(x, edge_next)
          # Only count length of selected edges that have no cycling infrastructure.
          j = j + (edge_next$d - (edge_next$d * edge_next$cycle_infra))
        }
      } else{
        # if there are no more edges in that community, do nothing
        x <- x
        j <- j
      }
    }
    i <- i+1
  }
  return(x)
}



# clear environment. Keep functions for next script 
rm(test, test_0, test2, graph_sf)


## adding igraph connected components function takes double the time 
#system.time({ growth_community_4(graph_sf, 30, "flow") })


