# function to get internal flows within a specified city. 
# returns rows where origin and destination match the specified city name
# works on 'flows' dataframe in '1_flow_data'

flows_internal <- function(name) {
  x <- flows %>% filter(city_origin == name, city_dest == name)
  return(x)
}

# function to filter MSOAs that are within a certain city
# only runs on the city_names dataframe in '1_flow_data'
msoas_in_city <- function(name) {
  x <- city_names %>% filter(city == name)
  return(x)
}


# function to split c(lat, lon) to two seperate columns  FROM JM London (https://github.com/r-spatial/sf/issues/231)
# lat = Y lon = X
split_lon_lat <- function(x, names = c("lon","lat")) {
  stopifnot(inherits(x,"sf") && inherits(sf::st_geometry(x),"sfc_POINT"))
  ret <- sf::st_coordinates(x)
  ret <- tibble::as_tibble(ret)
  stopifnot(length(names) == ncol(ret))
  x <- x[ , !names(x) %in% names]
  ret <- setNames(ret,names)
  dplyr::bind_cols(x,ret)
}


# get compact bounding box with buffer. CRS transformation is specific to UK. It needs to be modified so 
# that user can input a CRS that is appropriate to study area

###
# bb <- osmdata::getbb ("oxford uk", format_out = "polygon")
# Result of above query can be passed directly to streetnet, but we want to add a buffer. 
# Buffers can be added using expand in `dodgr_streetnet("oxford uk", expand = 0.05)`. the problem with this 
# is that it gets a rectangular bb. I want something more compact (i.e buffer around city boundary). This is 
# done to deal with RAM limitations
###

bb_buffer <- function(city, buffer){
  x <- osmdata::getbb (city, format_out = "sf_polygon") %>% 
    sf::st_transform(crs = 27700) %>%  # change crs to one that uses metres
    sf::st_buffer(dist = buffer) %>%     # add buffer in metres
    sf::st_transform(crs = 4326) %>%   # get original crs
    sf::st_coordinates()               # get coordinates since dodgr_streetnet takes matrix argument
  return(x)
}

# -------------------------------------------------------------------------------------------------------------


# snap centroids to lines

# function from https://stackoverflow.com/questions/51292952/snap-a-point-to-the-closest-point-on-a-line-segment-using-sf
# x = points, y = lines
st_snap_points = function(x, y, max_dist = 1000) {
  
  if (inherits(x, "sf")) n = nrow(x)
  if (inherits(x, "sfc")) n = length(x)
  
  out = do.call(c,
                lapply(seq(n), function(i) {
                  nrst = st_nearest_points(st_geometry(x)[i], y)
                  nrst_len = st_length(nrst)
                  nrst_mn = which.min(nrst_len)
                  if (as.vector(nrst_len[nrst_mn]) > max_dist) return(st_geometry(x)[i])
                  return(st_cast(nrst[nrst_mn], "POINT")[2])
                })
  )
  return(out)
}


# -------------------------------------------------------------------------------------------------------------


# Extract Dedicated Bicycle Infrastructure From OSM
# graph is an sf feature of the road network you have
# network is the OSM road network extracted using the dodgr package
infra_exists <- function(graph, network){
  
  # create a combined geometry with all edges matching either of the three conditions
  graph_cycle <- network %>% 
    filter(highway == 'cycleway' | bicycle == 'designated' | cycleway == 'track') %>%
    st_combine()
  
  # Get all features of graph_sf that have dedicated cycling infrastructure
  sel_sgbp <- st_within(x=graph, y=graph_cycle)
  sel_logical <- lengths(sel_sgbp) > 0
  graph_cycle <- graph[sel_logical, ]
  
  # We need to add a column in graph_sf to identify all edges with cycle infrastructure
  # add a cycle_infra column to graph_sf_cycle and give all edges a value of 1, then 
  # join with graph
  graph_cycle <-
    graph_cycle %>% st_drop_geometry() %>%
    mutate(cycle_infra= 1) %>%
    dplyr::select(c(edge_id, cycle_infra))
  
  #join the cycle_infra column to the original graph
  graph <- dplyr::left_join(graph, graph_sf_cycle, by = "edge_id")
  
  # all NA values in cycle_infra are those that had nothing to join to. It means they have no 
  # cycling infrastructure. We will give them a value of 0 for cycle_infra
  graph$cycle_infra[is.na(graph$cycle_infra)] <- 0
  
  return(graph)
}


# -------------------------------------------------------------------------------------------------------------

########## 2.1: FUNCTION FOR ASSIGNING ROAD EDGES TO MSOAS ###########

# Below function does the following:
# if road segment does not intersect with any msoa border, snap it to the nearesr msoa centroid
# if road segment interect (crosses) more than one msoa border, calculate the length of intersection with
# with all intersecting MSOAs and assign it to the one it intersect with most
# if road segment falls completely within one msoa, assign it to that msoa

assign_edge_to_polygon = function(x, y, z) {
  # x = sf with linestring features (road edges)
  # y = sf with polygon features (msoa borders)
  # z = sf with point features (msoa centroids)
  ##############
  #### this function requires a column in y and z named msoa11cd!!!! ####
  ###############
  if (inherits(x, "sf")) n = nrow(x)
  if (inherits(x, "sfc")) n = length(x)
  
  out = do.call(c,
                lapply(seq(n), function(i) {
                  # nrst is a list! It returns the msoa row number/s
                  nrst = st_intersects(st_geometry(x)[i], y)
                  # if intersect returns nothing, this edge is outside of all MSOA geometries
                  # get nearest msoa centroid to edge and assign it to it
                  if ( length (nrst[[1]]) == 0 ){
                    nrst = st_nearest_feature(st_geometry(x)[i], z)
                    msoa_code = as.character(z$msoa11cd[nrst[[1]]])
                  }
                  # if edge intersect with more than 1 msoa (does not fall completely inside 1), then
                  # find the length of intersection with each, and assign it to the one it intersects with more
                  else if ( length (nrst[[1]]) > 1 ){
                    # gets the msoa list position of the biggest intersection (intersection length with the different msoas is compared first)
                    a = which.max(st_length(st_intersection(st_geometry(x)[i], y))) 
                    # [[1]] to get the list element with the intersecting msoas
                    # nrst is assigned to the msoa return from a
                    nrst =  nrst[[1]][a]
                    msoa_code = as.character(y$msoa11cd[nrst[[1]]])
                  } 
                  # if edge falls completely inside 1 msoa, assign it to that msoa
                  else {
                    msoa_code = as.character(y$msoa11cd[nrst[[1]]])
                  }
                  # in all cases above, we get the msoa code by pointing to df$column[row number],
                  # where row number is retrieved from the nrst list through nrst[[1]]....ropey
                  return(msoa_code)
                })
  )
  out = dplyr::as_tibble(out)
  return(out)
}


# -------------------------------------------------------------------------------------------------------------


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
growth_one_seed <- function(graph, km, col_name) {
  
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
  graph <- graph %>% 
    filter(!(is.na(sequen))) %>% 
    arrange(sequen) # arrange in the order they were added
  return(graph)
}

# test <- growth_one_seed(graph_sf, 50, "flow")
# 
# plot(st_geometry(graph_sf), col = 'lightgrey')
# plot(test["sequen"], add = TRUE)
# 
# plot(st_geometry(graph_sf), col = 'lightgrey')
# plot(test["Community"], add = TRUE)


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

growth_existing_infra <- function(graph, km, col_name) {
  
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

# test <- growth_existing_infra(graph_sf, 50, "flow")
# # check km argument was respected 
# test %>% st_drop_geometry %>% group_by(cycle_infra) %>% summarize(length = sum(d))
# 
# 
# plot(st_geometry(graph_sf), col = 'lightgrey')
# plot(test["sequen"], add = TRUE)
# 
# plot(st_geometry(graph_sf), col = 'lightgrey')
# plot(test["Community"], add = TRUE)

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
growth_community <- function(graph, km, col_name) {
  
  ### check if km chosen is a reasonable number (using a predefined function)
  check_km_value(graph, km)
  
  # add sequen column
  graph$sequen <- NA
  # Group by community and get the edge with the highest flow in each group
  # to pass column name in function (specific to dplyr): https://stackoverflow.com/questions/480622dplyr-using-column-names-as-function-arguments
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
  graph <- graph %>% filter(!(is.na(sequen))) %>% 
    arrange(sequen) # arrange in the order they were added
  return(graph)
}

# test <- growth_community(graph_sf, 50, "flow")
# # check km argument was respected 
# test %>% st_drop_geometry %>% group_by(cycle_infra) %>% summarize(length = sum(d))
# 
# 
# # let's see if the seeds were correct. Main concern is to see if passing column name to the function worked
# test_0 <- test %>% dplyr::filter(sequen == 0)
# plot(test_0["Community"])
# 
# plot(st_geometry(graph_sf), col = 'lightgrey')
# plot(test["sequen"], add = TRUE)
# 
# plot(st_geometry(graph_sf), col = 'lightgrey')
# plot(test["Community"], add = TRUE)
# 
# # let's see which edges grow first
# #dplyr::filter isn't working so filtering with base r
# test2 <- test[test$sequen <= 30,]
# plot(test2["sequen"])
#      
# plot(st_geometry(graph_sf), col = 'lightgrey')
# plot(test2["sequen"], add = TRUE)

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

growth_community_2 <- function(graph, km, col_name) {
  
  ### check if km chosen is a reasonable number (using a predefined function)
  check_km_value(graph, km)
  
  # add sequence column
  graph$sequen <- NA
  # Group by community and get the edge with the highest flow in each group
  # to pass column name in function (specific to dplyr): https://stackoverflow.com/questions/480622dplyr-using-column-names-as-function-arguments
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
            graph <- graph %>% filter(!(is.na(sequen))) %>% 
              arrange(sequen) # arrange in the order they were added
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
  graph <- graph %>% filter(!(is.na(sequen))) %>% 
    arrange(sequen) # arrange in the order they were added
  return(graph)
}



# test <- growth_community_2(graph_sf, 500, "flow")
# 
# test %>% st_drop_geometry %>% group_by(cycle_infra) %>% summarize(length = sum(d))
# 
# plot(st_geometry(graph_sf), col = 'lightgrey')
# plot(test["Community"], add = TRUE)
# plot(test["Community"])



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


growth_community_3 <- function(graph, km, col_name) {
  
  ### check if km chosen is a reasonable number (using a predefined function)
  check_km_value(graph, km)
  
  # add sequence column
  graph$sequen <- NA
  # Group by community and get the edge with the highest flow in each group
  # to pass column name in function (specific to dplyr): https://stackoverflow.com/questions/480622dplyr-using-column-names-as-function-arguments
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
  graph <- graph %>% filter(!(is.na(sequen))) %>% 
    arrange(sequen) # arrange in the order they were added
  return(graph)
}

# test <- growth_community_3(graph_sf, 50, "flow")
# 
# test %>% st_drop_geometry %>% group_by(cycle_infra) %>% summarize(length = sum(d))
# 
# plot(st_geometry(graph_sf), col = 'lightgrey')
# plot(test["Community"], add = TRUE)
# plot(test["Community"])


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


growth_community_4 <- function(graph, km, col_name) {
  
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







