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

# ----------------------------------- ALGORITHM 1: UTILITARIAN GROWTH ----------------------------------------- #

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

growth_utilitarian <- function(graph, km, col_name) {
  
  ### check if km chosen is a reasonable number (using a predefined function)
  check_km_value(graph, km)
  # add empty columns for sequence, number of compenents in solution, and size of largest connected component
  graph <- graph %>% mutate(sequen= NA,
                            no_components = NA,
                            gcc_size = NA)
  # get all edges with cycling infrastructure - these are the starting point (sequen = 0)
  graph$sequen[graph$cycle_infra == 1] <- 0
  # we need a network representation to get no. of components and size of gcc using igraph
  net <- graph  %>% filter(!(is.na(sequen))) %>% as_sfnetwork()
  
  # calculate no of components and size of largest connected component (for current solution)
  graph$no_components[graph$cycle_infra == 1] <- igraph::count_components(net)
  graph$gcc_size[graph$cycle_infra == 1] <- components(net)$csize[which.max(components(net)$csize)]
  # i keeps track of which iteration a chosen edge was added in
  i <- 1
  # we keep track of the edges in the solution, so that we can identify the edges that neighbor them
  chosen <- graph %>% filter(!(is.na(sequen)))
  # j counts km added. We don't count segments that already have cycling infrastructure
  j <- sum(chosen$d) - sum(chosen$cycle_infra * chosen$d)
  
  #while length of chosen segments is less than specified length 
  while (j/1000 < km){
    # candidate list for selection: remove rows that have already been selected (i.e. sequen value is not NA)
    remaining <- graph %>% filter(is.na(sequen))
    # identify road segments that neighbour existing selection
    neighb_id <- graph$edge_id[which(graph$from_id %in% chosen$from_id | 
                                       graph$from_id %in% chosen$to_id |
                                       graph$to_id %in% chosen$from_id | 
                                       graph$to_id %in% chosen$to_id)]
    # get neighbouring edges
    neighb <- remaining %>% filter(edge_id %in% neighb_id)
    # get id of best neighboring edge
    edge_sel <- neighb$edge_id[which.max(neighb[[col_name]])]
    # assign a sequence to the selected edge
    graph$sequen[graph$edge_id == edge_sel] <- i
    # we need a network representation to get no. of components and size of gcc using igraph
    net <- graph  %>% filter(!(is.na(sequen))) %>% as_sfnetwork()
    # get no of components and size of largest connected component at this iteration
    graph$no_components[graph$edge_id == edge_sel] <- igraph::count_components(net)
    graph$gcc_size[graph$edge_id == edge_sel] <- components(net)$csize[which.max(components(net)$csize)]
    # modify the 'chosen' sf so that it includes the new edge (new edge no longer has sequen == NA)
    chosen <- graph %>% filter(!(is.na(sequen)))
    # iterate sequence
    i = i+1
    # Update length of solution. Only count length of chosen edges (and don't count if edge has cycling infrastructure)
    j = sum(chosen$d) - sum(chosen$cycle_infra * chosen$d)
    
  }
  # keep only edges/rows that have been chosen
  graph <- graph %>% filter(!(is.na(sequen))) %>% 
    arrange(sequen) # arrange in the order they were added
  return(graph)
}

# test <- growth_utilitarian(graph_sf, 50, "flow")
# # check km argument was respected 
# test %>% st_drop_geometry %>% group_by(cycle_infra) %>% summarize(length = sum(d))
# 
# 
# plot(st_geometry(graph_sf), col = 'lightgrey')
# plot(test["sequen"], add = TRUE)
# 
# plot(st_geometry(graph_sf), col = 'lightgrey')
# plot(test["Community"], add = TRUE)

# ----------------------------------- ALGORITHM 2: EGALITARIAN GROWTH ----------------------------------------- #

###########################################################################################################  
### WE START WITH ALL EDGES THAT ALREADY HAVE CYCLING INFRASTRUCTURE.THESE ARE THE BEGINNING OF THE SOLUTION.##
### TO ENSURE THAT THERE IS AT LEAST ONE EDGE FROM EACH COMMUNITY, WE GET THE EDGE WITH THE HIGHEST FLOW IN 
### EACH COMMUNITY AND APPEND IT TO THE SOLUTION AT SEQUENCE 0. ###
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


growth_egalitarian <- function(graph, km, col_name) {
  
  ### check if km chosen is a reasonable number. Function is defined in the beginning
  check_km_value(graph, km)
  
  # add empty columns for sequence, number of compenents in solution, and size of largest connected component
  graph <- graph %>% mutate(sequen= NA,
                            no_components = NA,
                            gcc_size = NA)
  # Group by community and get the edge with the highest flow in each group
  # to pass column name in function (specific to dplyr): https://stackoverflow.com/questions/480622dplyr-using-column-names-as-function-arguments
  # we get max flow per group, and then get max distance on result in case of ties (so that we end up with 1 row per group)
  x <- graph %>% group_by(Community) %>% 
    slice_max(order_by = !! sym(col_name)) %>% 
    slice_max(order_by = d) %>% ungroup()
  # get all edges with cycling infrastructure
  y <- graph %>% dplyr::filter(cycle_infra == 1) 
  x <- rbind(x, y)
  # remove duplicates
  x <- dplyr::distinct(x, edge_id, .keep_all = TRUE) 
  # assign sequence 0 to all edges that are in x
  graph$sequen[graph$edge_id %in% x$edge_id] <- 0
  # we need a network representation to get no. of components and size of gcc using igraph
  net <- graph  %>% filter(!(is.na(sequen))) %>% as_sfnetwork()
  # calculate no of components and size of largest connected component (for current solution)
  # only add the values to the rows in the graph that are also in x
  graph$no_components[graph$edge_id %in% x$edge_id] <- igraph::count_components(net)
  graph$gcc_size[graph$edge_id %in% x$edge_id] <- components(net)$csize[which.max(components(net)$csize)]
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
      chosen    <- split[[k]] %>% filter(!(is.na(sequen)))
      # edges in community k that have not been chosen yet
      remaining <- split[[k]] %>% filter(is.na(sequen))
      # we need a network representation to get no. of components and size of gcc using igraph
      net <- graph  %>% filter(!(is.na(sequen))) %>% as_sfnetwork()
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
          # assign a sequence to the selected edge
          graph$sequen[graph$edge_id == edge_sel] <- i
          # we need it here as well because this is where we filter nas for the 'chosen' variable
          split[[k]]$sequen[split[[k]]$edge_id == edge_sel] <- i
          # get no of components and size of largest connected component at this iteration
          graph$no_components[graph$edge_id == edge_sel] <- igraph::count_components(net)
          graph$gcc_size[graph$edge_id == edge_sel] <- components(net)$csize[which.max(components(net)$csize)]
          
          # Only count length of selected edges that have no cycling infrastructure. (edge length - (edge_length*cycling_infra binary value))
          j = j + ((graph$d[graph$edge_id == edge_sel]) - (graph$d[graph$edge_id == edge_sel] * graph$cycle_infra[graph$edge_id == edge_sel]))
          
        } else{
          #get the edge_id of the edge with the highest flow out of the remaining df
          edge_sel <- remaining$edge_id[which.max(remaining[[col_name]])]
          # assign a sequence to the selected edge
          graph$sequen[graph$edge_id == edge_sel] <- i
          # we need it here as well because this is where we filter nas for the 'chosen' variable
          split[[k]]$sequen[split[[k]]$edge_id == edge_sel] <- i
          # get no of components and size of largest connected component at this iteration
          graph$no_components[graph$edge_id == edge_sel] <- igraph::count_components(net)
          graph$gcc_size[graph$edge_id == edge_sel] <- components(net)$csize[which.max(components(net)$csize)]
          
          # Only count length of selected edges that have no cycling infrastructure. (edge length - (edge_length*cycling_infra binary value))
          j = j + ((graph$d[graph$edge_id == edge_sel]) - (graph$d[graph$edge_id == edge_sel] * graph$cycle_infra[graph$edge_id == edge_sel]))
        }
      } else{
        # if there are no more edges in that community, do nothing
        graph <- graph
        j <- j
      }
    }
    i <- i+1
  }
  graph <- graph %>% filter(!(is.na(sequen))) %>% 
    arrange(sequen) # arrange in the order they were added
  
  return(graph)
}


# test <- growth_egalitarian(graph_sf, 400, "flow")
# 
# graph_sf %>% st_drop_geometry %>% filter(cycle_infra ==0) %>% group_by(Community) %>% summarize(length = sum(d)/ 1000)
# test %>% ungroup %>% st_drop_geometry %>% filter(cycle_infra ==0) %>% group_by(Community) %>% summarize(length = sum(d)/ 1000)
# 
# 
# 
# test %>% st_drop_geometry %>% group_by(cycle_infra) %>% summarize(length = sum(d))
# 
# plot(st_geometry(graph_sf), col = 'lightgrey')
# plot(test["Community"], add = TRUE)
# plot(test["Community"])
# plot(test["sequen"])




## adding igraph connected components function takes double the time 
#system.time({ growth_egalitarian(graph_sf, 30, "flow") })

