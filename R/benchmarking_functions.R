library(igraph)
library(sf)
library(sfnetworks)
library(dplyr)
library(rbenchmark)

test <- readRDS(paste0("../data/", chosen_city, "/graph_with_flows_default_communities.RDS"))


growth_one_seed_modified <- function(graph, km, col_name) {
  
  ### check if km chosen is a reasonable number (using a predefined function)
  check_km_value(graph, km)
  # add an empty sequence column
  graph <- graph %>% mutate(sequen= NA)
  #get edge_id of edge with highest flow
  edge_sel <- graph$edge_id[which.max(graph[[col_name]])]
  # assign a sequence  to the selected edge
  #graph <- within(graph, sequen[edge_id == edge_sel] <- 0)
  graph$sequen[graph$edge_id == edge_sel] <- 0
  # i keeps track of which iteration a chosen edge was added in
  i <- 1
  # we keep track of the edges in the solution, so that we can identify the edges that neighbor them
  # edges in the solution are those that have been assigned a 'sequen' value
  chosen <- graph %>% filter(!(is.na(sequen)))
  # j counts km added. We don't count segments that already have cycling infrastructure
  j <- sum(chosen$d) - sum(chosen$cycle_infra * chosen$d)
  #while length of chosen segments is less than specified length 
  while (j/1000 < km){
    # candidate list for selection: remove rows that have already been selected (i.e. their sequen value is not NA)
    remaining <- graph %>% filter(is.na(sequen))
    # identify road segments that neighbour existing selection
    neighb_id <- graph$edge_id[which(graph$from_id %in% chosen$from_id | 
                                       graph$from_id %in% chosen$to_id |
                                       graph$to_id %in% chosen$from_id | 
                                       graph$to_id %in% chosen$to_id)]
    # get neighbouring edges
    neighb <- remaining %>% filter(edge_id %in% neighb_id)
    # get edge_id of best neighboring edge
    edge_sel <- neighb$edge_id[which.max(neighb[[col_name]])]
    # assign a sequence to the selected edge
    graph$sequen[graph$edge_id == edge_sel] <- i
    # modify the 'chosen' sf so that it includes the new edge (new edge no longer has sequen == NA)
    chosen <- graph %>% filter(!(is.na(sequen)))
    # iterate sequence
    i = i+1
    # Update length of solution. Only count length of chosen edges (and don't count if edge has cycling infrastructure)
    j = sum(chosen$d) - sum(chosen$cycle_infra * chosen$d)
  }
  # keep only edges/rows that have been chosen
  graph <- graph %>% filter(!(is.na(sequen)))
  return(graph)
}

old <- growth_one_seed_OLD(test, 30, "flow")
new <- growth_one_seed_modified(test, 30, "flow")
# it is faster
system.time({growth_one_seed_OLD(test, 20, "flow")})
system.time({growth_one_seed_modified(test, 20, "flow")})



growth_existing_infra_modified <- function(graph, km, col_name) {
  
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
  graph <- graph %>% filter(!(is.na(sequen)))
  return(graph)
}

old <- growth_existing_infra_OLD(test, 10, "flow")
new <- growth_existing_infra_modified(test, 10, "flow")
# it is faster
system.time({growth_existing_infra_OLD(test, 100, "flow")})
system.time({growth_existing_infra_modified(test, 100, "flow")})





growth_community_modified <- function(graph, km, col_name) {
  
  ### check if km chosen is a reasonable number (using a predefined function)
  check_km_value(graph, km)
  
  # add sequen column
  graph$sequen <- NA
  # Group by community and get the edge with the highest flow in each group
  # to pass column name in function (specific to dplyr): https://stackoverflow.com/questions/48062213/dplyr-using-column-names-as-function-arguments
  # we get max flow per group, and then get max distance on result in case of ties (so that we end up with 1 row per group)
  x <- graph %>% group_by(Community) %>% 
    slice_max(order_by = !! sym(col_name)) %>% 
    slice_max(order_by = d) 
  # assign sequence 0 to all edges that are in x
  graph$sequen[graph$edge_id %in% x$edge_id] <- 0
  # we keep track of the edges in the solution, so that we can identify the edges that neighbor them
  chosen <- graph %>% filter(!(is.na(sequen)))
  # i keeps track of which iteration a chosen edge was added in
  i <- 1
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
    # modify the 'chosen' sf so that it includes the new edge (new edge no longer has sequen == NA)
    chosen <- graph %>% filter(!(is.na(sequen)))
    # iterate
    i = i+1
    # Only count length of selected edges that have no cycling infrastructure.
    j = sum(chosen$d) - sum(chosen$cycle_infra * chosen$d)
  }
  # keep only edges/rows that have been chosen
  graph <- graph %>% filter(!(is.na(sequen)))
  return(graph)
}

old <- growth_community_OLD(test, 10, "flow")
new <- growth_community_modified(test, 10, "flow")
# it is faster
system.time({growth_community_OLD(test, 200, "flow")})
system.time({growth_community_modified(test, 200, "flow")})




x <- graph_sf %>% group_by(Community) %>% 
  slice_max(order_by = flow) %>% 
  slice_max(order_by = d) 

x2 <- graph_sf %>% group_by(Community) %>% 
  slice_max(order_by = flow) %>% 
  slice_max(order_by = d) %>%
  ungroup()



growth_community_2_modified <- function(graph, km, col_name) {
  
  ### check if km chosen is a reasonable number (using a predefined function)
  check_km_value(graph, km)
  
  # add sequence column
  graph$sequen <- NA
  # Group by community and get the edge with the highest flow in each group
  # to pass column name in function (specific to dplyr): https://stackoverflow.com/questions/48062213/dplyr-using-column-names-as-function-arguments
  # we get max flow per group, and then get max distance on result in case of ties (so that we end up with 1 row per group)
  x <- graph %>% group_by(Community) %>% 
    slice_max(order_by = !! sym(col_name)) %>% 
    slice_max(order_by = d) 
  # assign sequence 0 to all edges that are in x
  graph$sequen[graph$edge_id %in% x$edge_id] <- 0
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
  # we keep track of the edges in the solution, so that we can identify the edges that neighbor them
  chosen <- graph %>% filter(!(is.na(sequen)))
  # i keeps track of which iteration a chosen edge was added in
  i <- 1
  # j counts km added. We don't count segments that already have cycling infrastructure
  j <- sum(chosen$d) - sum(chosen$cycle_infra * chosen$d)
  
  #while length of chosen segments is less than the specified length 
  while (j/1000 < km){
    # for each community
    for (k in 1:length(split)){
      # edges in community k that have already been chosen 
      chosen    <- split[[k]] %>% filter(!(is.na(sequen)))
      # edges in community k that have not been chosen yet
      remaining <- split[[k]] %>% filter(is.na(sequen))
      # if there are still edges in the community that haven't been chosen
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
          # assign a sequence to the selected edge. Assign it to the graph sf and to the split sf
          graph$sequen[graph$edge_id == edge_sel] <- i
          # we need it here as well because this is where we filter nas for the 'chosen' variable
          split[[k]]$sequen[split[[k]]$edge_id == edge_sel] <- i
          
          # Only count length of selected edges that have no cycling infrastructure. (edge length - (edge_length*cycling_infra binary value))
          j = j + ((graph$d[graph$edge_id == edge_sel]) -  (graph$d[graph$edge_id == edge_sel] * graph$cycle_infra[graph$edge_id == edge_sel]))
        } else{
          # if neighb is empty, add the community number to the check_conn vector
          check_conn[k] <- k
          # if check_conn vector becomes populated with all communities, break out of function
          if (!is.na(sum(check_conn))){
            message(paste0("There are no more connected edges to add for all communities. The returned object has ", round(j/1000),
                           "km out of the specified ", km, "km"))
            graph <- graph %>% filter(!(is.na(sequen)))
            return(graph)
          }
        }
      } else{
        graph <- graph
        j <- j
      }
    }
    i <- i+1
  }
  graph <- graph %>% filter(!(is.na(sequen)))
  return(graph)
}


old <- growth_community_2_OLD(test, 200, "flow")
new <- growth_community_2_modified(test, 200, "flow")

system.time({growth_community_2_OLD(test, 300, "flow")})
system.time({growth_community_2_modified(test, 300, "flow")})



growth_community_3_modified <- function(graph, km, col_name) {
  
  ### check if km chosen is a reasonable number (using a predefined function)
  check_km_value(graph, km)
  
  # add sequence column
  graph$sequen <- NA
  # Group by community and get the edge with the highest flow in each group
  # to pass column name in function (specific to dplyr): https://stackoverflow.com/questions/48062213/dplyr-using-column-names-as-function-arguments
  # we get max flow per group, and then get max distance on result in case of ties (so that we end up with 1 row per group)
  x <- graph %>% group_by(Community) %>% 
    slice_max(order_by = !! sym(col_name)) %>% 
    slice_max(order_by = d) 
  # assign sequence 0 to all edges that are in x
  graph$sequen[graph$edge_id %in% x$edge_id] <- 0
  ####################
  # split the graph into a list of dataframes with length = number of communities
  split <- graph %>%
    group_split(Community)

  ####################
  # we keep track of the edges in the solution, so that we can identify the edges that neighbor them
  chosen <- graph %>% filter(!(is.na(sequen)))
  # i keeps track of which iteration a chosen edge was added in
  i <- 1
  # j counts km added. We don't count segments that already have cycling infrastructure
  j <- sum(chosen$d) - sum(chosen$cycle_infra * chosen$d)
  
  #while length of chosen segments is less than the specified length 
  while (j/1000 < km){
    
    # for each community
    for (k in 1:length(split)){
      # edges in community k that have already been chosen 
      chosen    <- split[[k]] %>% filter(!(is.na(sequen)))
      # edges in community k that have not been chosen yet
      remaining <- split[[k]] %>% filter(is.na(sequen))
      
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
          # assign a sequence to the selected edge. Assign it to the graph sf and to the split sf
          graph$sequen[graph$edge_id == edge_sel] <- i
          # we need it here as well because this is where we filter nas for the 'chosen' variable
          split[[k]]$sequen[split[[k]]$edge_id == edge_sel] <- i
          
          # Only count length of selected edges that have no cycling infrastructure. (edge length - (edge_length*cycling_infra binary value))
          j = j + ((graph$d[graph$edge_id == edge_sel]) -  (graph$d[graph$edge_id == edge_sel] * graph$cycle_infra[graph$edge_id == edge_sel]))
        } else{
          #get the edge_id of the edge with the highest flow out of the neighb df
          edge_sel <- remaining$edge_id[which.max(remaining[[col_name]])]
          graph$sequen[graph$edge_id == edge_sel] <- i
          # we need it here as well because this is where we filter nas for the 'chosen' variable
          split[[k]]$sequen[split[[k]]$edge_id == edge_sel] <- i
          
          # Only count length of selected edges that have no cycling infrastructure. (edge length - (edge_length*cycling_infra binary value))
          j = j + ((graph$d[graph$edge_id == edge_sel]) -  (graph$d[graph$edge_id == edge_sel] * graph$cycle_infra[graph$edge_id == edge_sel]))
        }
      } else{
        graph <- graph
        j <- j
      }
    }
    i <- i+1
  }
  graph <- graph %>% filter(!(is.na(sequen)))
  return(graph)
}


old <- growth_community_3_OLD(test, 10, "flow")
new <- growth_community_3_modified(test, 10, "flow")

system.time({growth_community_3_OLD(test, 30, "flow")})
system.time({growth_community_3_modified(test, 30, "flow")})



growth_community_4_modified <- function(graph, km, col_name) {
  
  ### check if km chosen is a reasonable number. Function is defined in the beginning
  check_km_value(graph, km)
  
  # add empty columns for sequence, number of compenents in solution, and size of largest connected component
  graph <- graph %>% mutate(sequen= NA,
                            no_components = NA,
                            gcc_size = NA)
  # Group by community and get the edge with the highest flow in each group
  # to pass column name in function (specific to dplyr): https://stackoverflow.com/questions/48062213/dplyr-using-column-names-as-function-arguments
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
  graph <- graph %>% filter(!(is.na(sequen)))
  return(graph)
}


old <- growth_community_4_OLD(test, 50, "flow")
new <- growth_community_4_modified(test, 50, "flow")

system.time({growth_community_4_OLD(test, 150, "flow")})
system.time({growth_community_4_modified(test, 150, "flow")})



