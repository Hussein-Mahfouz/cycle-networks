Road Segment Prioritization for Bicycle Infrastructure
================
2021-01-04

# Ideas and discussion

  - Intro: possible trim down substantially then add some literature in
    (a) Calculating Potential Demand \[DONE\]/ (b) Routing \[DONE\]/ (c)
    Road Segment Prioritization
  - Community Detection: Where in the document should this section be?
    It is now before Road Segment Prioritization, but I can merge them
  - Should we use other cities for the sake of comparison (compare
    communities, road types etc)
  - How to add tables properly (they are now added using latex code
    which only shows up when outputting to pdf)
  - Footnotes are sometimes split between pages. How do I keep them on
    the same page?
  - What is the best way to write pseudocode (Steps for Algorithm 1 and
    2)

<!-- ## Missing Data -->

<!-- The following file cannot be synced to github due to its size. -->

<!-- The file is neseccary for the scripts to run. Below is a link -->

<!-- to where you can download it, and instructions on where to place it -->

<!-- in the repo file structure -->

<!-- Middle Layer Super Output Areas (December 2011) Boundaries: -->

<!--   - Source: -->

<!--     <http://geoportal.statistics.gov.uk/datasets/826dc85fb600440889480f4d9dbb1a24_0> -->

<!--   - Location in Repo: data-raw/MSOA\_2011\_Boundaries/\[Add files here\] -->

<!-- ----- -->

<!-- ## Scripts -->

<!-- The scripts should be run in the order they are numbered in (and listed -->

<!-- in here). The only exception is \_x\_dodgr\_weighting\_profiles.R. -->

<!-- Check the readme -->

<!-- [here](https://github.com/Hussein-Mahfouz/Bicycle-Network-Optimization) -->

<!-- for detailed info on each script -->

<!-- Keywords -->

<!-- ======== -->

<!-- Highlights -->

<!-- ======== -->

# Introduction

The 2015 Paris agreement (UN 2015) acknowledged that fundamental changes
to societies and economies are necessary to mitigate climate change.
Like other sectors, transport is under substantial pressure to
decarbonise resulting in a number of technical innovations including
electric vehicles. But new vehicle technologies can only go so far and
do not tackle parallel problems such as congestion, road traffic
casualties and physical inactivity (Brand et al. 2020).

In this context, interest and investment in active modes is growing. The
benefits of the latter extend beyond congestion and the environment, as
it promises to help alleviate what is referred to as the pandemic of
global inactivity; physical inactivity is on the rise and has become the
4th highest cause of death globally (Kohl 3rd et al. 2012). Various
studies have documented the association between active transport and
lower risk of disease, including cancer and cardiovascular disease
(Celis-Morales et al. 2017; Jarrett et al. 2012; Patterson et al. 2020).
In the wake of the Covid-19 pandemic, and the resulting reduced capacity
of public transport, the UK government has pledged to invest billions of
pounds to improve walking and cycling infrastructure across the country.
While this unprecedented sum is an opportunity to reshape cities in a
way that improves the well-being of citizens, it does come with a
warning:

> “Inadequate cycling infrastructure discourages cycling and wastes
> public money. Much cycling infrastructure in this country is
> inadequate. It reflects a belief, conscious or otherwise, that hardly
> anyone cycles, that cycling is unimportant and that cycles must take
> no meaningful space from more important road users, such as motor
> vehicles and pedestrians - (DfT 2020b)”

The funding on its own is therefore no guarantee of a change in
commuting across the country; it must be used to design adequate cycling
infrastructure that is based on motivators and deterrents to cycling.

A considerable amount of research has been done towards that end.
Segregated cycling infrastructure\[1\] has been shown to increase
cycling uptake (Aldred, Croft, and Goodman 2019; Goodman et al. 2014;
Marqués et al. 2015), with the separation from motorized vehicles being
key (Winters et al. 2011). Revealed preference of cyclists shows that
they are willing to deviate from the most efficient routes in order to
commute on safer roads (Crane et al. 2017). However, such deviations are
only considered if they do not considerably increase route circuitry;
behaviour studies have found that the probability of choosing a route
decreases in proportion to its length relative to the shortest route
(Broach, Gliebe, and Dill 2011; Winters et al. 2010). Another defining
feature for cycling infrastructure is how well connected it is. Cyclists
prefer cohesive infrastructure, particularly when cycling on arterial
roads with high levels of motorized traffic (Stinson and Bhat 2003), and
the lack of well-connected cycling infrastructure is one of the main
obstacles to increasing cycling uptake (Caulfield, Brick, and McCarthy
2012). While direct and cohesive cycling networks have been shown to
positively impact cycling rates, density\[2\] of the cycling network is
also vital (Schoner and Levinson 2014).

As noted by Buehler and Dill (2016), there has been a shift in focus
from localized (street or intersection) level planning towards planning
based on studying the cycling network as a whole since the turn of the
21<sup>st</sup> century. They emphasize the promise of this shift in
capturing the network-wide effect of street-level interventions.
*Optimization* techniques have been used to propose improvements to
cycling networks. Mesbah, Thompson, and Moridpour (2012) propose a
bi-level formulation to optimize allocation of cycling lanes to the
network without exceeding a set budget. The upper level is the proposed
interventions and the lower level is the route choices made by users in
reaction to changes in the network. The problem accounts for the effect
of cycling lanes on car traffic, and attempts to maximize utilization of
said lanes with minimal impact on car travel times. To improve cohesion
of the suggested network, a constraint is added so that each link\[3\]
with a bike lane should be connected to at least one destination. Car
usage is not considered by Mauttone et al. (2017), who develop an
optimization framework that aims to minimize the total user cost of
cycling on the network. The aggregate flow on links is obtained by using
shortest paths to route existing cycling demand onto the road network,
and the solution is a proposed set of links where cycling infrastructure
should be added in order to minimize the overall travel cost of cyclists
across the network. The cost of traversing a link is given as a function
of its length and whether or not it has cycling infrastructure, and a
discontinuity penalty is also added to prioritize connected road
segments. The problem has also been solved by attempting to find the
minimum cost of improving roadway links to meet a desired level of
service (LOS) (Duthie and Unnikrishnan 2014). In this formulation, all
OD pairs need to be connected by roads that meet the desired LOS, and a
directness constraint is added so that paths between OD pairs do not
exceed a certain multiple of the shortest path.

These problem formulations do not explicitly solve for continuity, which
is dealt with using a either (a) a constraint specifying that each link
with a bike lane should be connected to at least one destination
(Mesbah, Thompson, and Moridpour 2012), (b) a constraint on deviation
from shortest paths (Duthie and Unnikrishnan 2014), or (c) a
discontinuity penalty (Mauttone et al. 2017). To solve for continuity,
the graph-theoretic concept of *connected components*, has been used.
Natera et al. (2019) study the existing cycling network in terms of its
disconnected components and introduce two different algorithms to
connect these components by their most critical links and, in doing so,
measure the size of the growth of the largest connected component as a
function of the kilometers of network added. They observe that small
investments at strategic points have a large impact on connectivity in
most cases. The concept of connected components is also at the core of
the methodology proposed by Olmos et al. (2020). After routing the
cycling demand onto the network links, they use percolation theory to
filter out the links based on the aggregate flow\[4\] passing through
them, varying the flow threshold for filtering to identify the minimum
flow at which the whole city is connected by a giant component. The
results show a cycling network that connects the entire city, and
subtracting links intersecting with current cycling infrastructure
identifies links proposed for intervention.

The problem formulations outlined above look at the network as a whole
when attempting to improve it. An alternative approach is to identify
the different sub-networks that exist within the larger network, and
work on improving each separately. Trip patterns in a city are not
uniformly distributed geographically, and *community finding* methods
have been used to partition study areas into localized areas that
experience a disproportionate number of trips within them. Akbarzadeh,
Mohri, and Yazdian (2018) use a modularity maximization approach
(Blondel et al. 2008) on taxi trip data to identify 7 different
communities in the city of Isfahan, Iran. An optimization problem is
then formulated to connect nodes within each community with cycling
infrastructure. The emphasis is on connectivity within the communities,
not between them. Bao et al. (2017) adopt a similar methodology, but use
hierarchical clustering to specify the desired number of clusters. They
use a greedy network expansion algorithm, where the link with the
highest benefit-cost ratio in each cluster is selected, and the network
is grown by adding neighboring links to the solution until a budget
limit is met. The benefit is the flow on the link, and each link is
assigned a cost based on current road conditions.

All of these network-level methodologies are underpinned by different
ethical principles, even though these principles are not explicitly
acknowledged by the authors. This is important since different ethical
principles constitute different problem formulations and targets.
Broadly speaking, transport appraisal can be based on either utilitarian
or egalitarian principles. The former seeks to maximize the overall
benefit, while the latter is concerned with a fair distribution of
benefits (Jafino, Kwakkel, and Verbraeck 2020). Nahmias-Biran, Martens,
and Shiftan (2017) criticize the utilitarian approach that has been
historically popular in the evaluation of transport investments,
explaining how the maximization of overall benefit fails to account for
the distribution of that benefit among communities or individuals.
Lucas, Van Wee, and Maat (2016) explain how transport studies have
traditionally looked at the bigger picture without studying the
distribution of investments on the different parts of the study area,
and go on to propose an egalitarian approach that ensures the
dis-aggregation of transport policy benefits across the study area.
Pereira, Schwanen, and Banister (2017) also emphasize the need for a
more egalitarian approach to transport planning. They highlight
accessibility as a cornerstone of distributive justice, and contend that
policies should aim to distribute investments in a way that minimizes
spatial variations in accessibility. This research attempts to compare
the two principles, and in doing so determine whether a methodology
formulated based on an egalitarian approach can be feasible in designing
a cycling network that aligns with motivators and deterrents to cycling.
**Write some more here?**

# Data and Geographical Scale of Analysis

The approach is based on origin-destination (OD), which can be obtained
from many sources. In this paper we use open access data from the UK
census (ONS 2011), which contains aggregate statistics on number of
commuters between Middle layer Super Output Area (MSOA) zones, which
have an average population of just over 8000 (ONS 2018).

# Calculating Potential Cycling Demand

Using existing cycling demand to inform decisions on where cycling
infrastructure should be added reinforces existing cycling patterns and
ignores potential cycling demand that could be satisfied by a connected
network. To avoid this issue, Duthie and Unnikrishnan (2014) choose to
ignore existing demand completely, and focus on creating a network that
connects the entire study area. Olmos et al. (2020) obtain the distance
distribution of cyclists using a smartphone-based bicycle GPS data, and
then use a rejection-sampling algorithm on the OD data of the study area
to match the potential demand distribution to the distribution obtained
from GPS data.

For our purposes, we use a logistic regression model to calculate
potential cycling demand. The model is adopted directly from the
Propensity to Cycle Tool (PCT) (Lovelace et al. 2017). The PCT estimates
the proportion of cyclists (\(\boldsymbol{C_{p}}\)) for each MSOA pair
should the government achieve its target of doubling cycling by 2025.
The logistic regression model used to calculate \(\boldsymbol{C_{p}}\)
has the following parameters:

where **d** and **s** are the distance and slope respectively for the OD
pair. The authors use square and square-root distance terms “to capture
the non-linear impact of distance on the likelihood of cycling”, and
interaction terms to capture the combined effect of slope and distance
(Lovelace et al. 2017).

The potential demand calculations show that the current and potential
number of cyclists both follow a bell-shaped distribution, with the
number of trips peaking around the 3-4km commuting distance and then
going back down for longer distances (see Figure
<a href="#fig:potdemhistograms">1</a>).

<div class="figure">

<img src="data/Manchester/Plots/histogram_distance_all_vs_cycling.png" alt="Distribution of Potential Cycling Demand" width="32%" /><img src="data/Manchester/Plots/histogram_distance_all_vs_cycling_potential.png" alt="Distribution of Potential Cycling Demand" width="32%" /><img src="data/Manchester/Plots/histogram_distance_cycling_potential_vs_current.png" alt="Distribution of Potential Cycling Demand" width="32%" />

<p class="caption">

Figure 1: Distribution of Potential Cycling Demand

</p>

</div>

<div class="figure">

<img src="data/Manchester/Plots/desire_facet_cycling.png" alt="Current and Potential Cycling Demand" width="75%" />

<p class="caption">

Figure 2: Current and Potential Cycling Demand

</p>

</div>

It should be noted that the calculations assume a future that is
constrained by physical geography; i.e. we consider cycling in the
traditional sense. Recently there have been various micro-mobility
solutions, including e-bikes, that allow commuters to traverse longer
distances and hillier roads with less effort than traditional bicycles.
While these modes would probably be associated with less geographical
impedance, it is beyond the scope of this work to integrate that into
the analysis. Doing so is partially restricted by the lack of data on
the proliferation of these modes, which raises the point that perhaps
the census data category of \`Bicycle’ is too vague, and should be
further dis-aggregated to distinguish between traditional bicycles and
other forms of micro-mobility.

# Routing

The next step is to route the potential cycling demand
(\(\boldsymbol{C_{p}}\)) between all OD pairs onto the road network.
<!-- This expands on the work of @mauttone2017bicycle, by going beyond simply favoring roads with existing cycling infrastructure to creating a hierarchy of road preference. -->

To conduct routing, the following is considered:

1.  **Cyclist Preference**: Work done by Dill and McNeil (2013) on
    examining cyclist typologies determined that around 60% of Portland
    residents fit under the *interested but concerned* category. These
    were people that enjoyed cycling but avoided it due safety concerns.
    The key to encouraging this group was to create a low-stress cycling
    network, not only though segregated infrastructure but also by
    planning routes that passed through residential streets.
2.  **Low-Traffic Neighborhoods**: The UK Department for Transport is
    allocating funding to local authorities to invest in Active
    Transport, partially through the creation of LTNs (DfT 2020b). This
    includes closing off residential streets to motorized traffic.
3.  **Existing Cycling Infrastructure**: Utilizing existing cycling
    infrastructure makes economic sense, as small investments may lead
    to large connectivity gains as the disconnected cycling
    infrastructure gets joined together.

The above points are accounted for by using a weighted road network for
routing. This has previously been done by multiplying all road segments
without cycling infrastructure by an impedance factor (Mauttone et al.
2017), or by assigning a weight to the road segment proportional to the
investment cost of bringing it to an acceptable level of stress for
cycling (Duthie and Unnikrishnan 2014). Our approach is similar to the
latter, as we create a weighting profile that is adjusted to favor less
stressful streets (based on information from Table
<a href="#table:osmroadtypes"><strong>??</strong></a>), and roads with
existing cycling infrastructure. We believe this to be more practical
than the approach adopted by Mauttone et al. (2017), as it goes beyond
simply favoring roads with existing cycling infrastructure to creating a
hierarchy of road preference based on perceived stress levels. The
approach is also in line with the creation of LTNs, as residential
streets are those where motorized traffic is most likely to be banned in
the creation of LTNs.

<!-- **ADD TABLE - THIS IS BASIC** -->

<!-- ```{r, echo=FALSE, message = FALSE} -->

<!-- weight_profiles <- readxl::read_excel("Paper/paper_tables.xlsx", sheet = "Weighting Profile") -->

<!-- knitr::kable(weight_profiles, -->

<!--              caption = "Weighting Profiles") -->

<!-- ``` -->

A weighted distance \(\boldsymbol{d_{w}}\) for each road segment is
calculated as following:\[5\]

$$

where \(\boldsymbol{d_{unw}}\) is the unweighted distance and
\(\boldsymbol{W}\) is the weight from Table .

All weights are between 0 and 1, and the values in the  profile are
chosen so as to be inversely proportional to the stress level
experienced by cyclists on them. The  weighting profile is used to
compare increases in route length resulting from two different
approaches:

1.  **Weighted**: Relatively high impedance on Primary and Trunk roads
    (to minimize cycling on them).
2.  **Weighted\_2**: Avoiding Primary and Trunk Roads completely.

Comparing the cycling demand routed on the weighted and unweighted road
network allows us to get a better understanding of the importance of
different road types. In the case of Manchester, trunk roads bisect the
city and are a major part of unweighted shortest paths (Figure
<a href="#fig:flowsfacetunweighted">3</a>). On the other hand, cycleways
are not part of unweighted shortest paths, and so very little of the
cycling demand is routed through them. In the weighted network,
cycleways are much better utilized, and the majority of the cycling
demand passes through tertiary roads, as expected.

<div class="figure">

<img src="data/Manchester/Plots/flows_facet_unweighted_Manchester.png" alt="Flow Results Based on **Unweighted** Shortest Paths (Manchester)" width="90%" />

<p class="caption">

Figure 3: Flow Results Based on **Unweighted** Shortest Paths
(Manchester)

</p>

</div>

<div class="figure">

<img src="data/Manchester/Plots/flows_facet_weighted_Manchester.png" alt="Flow Results Based on **Weighted** Shortest Paths (Manchester)" width="90%" />

<p class="caption">

Figure 4: Flow Results Based on **Weighted** Shortest Paths (Manchester)

</p>

</div>

<!-- The difference between aggregate flow on weighted and unweighted networks is dependant on the road network of the city. Comparing Manchester to Nottingham, we see that trunk roads are much more important in the former, as over 25\% of flow on the unweighted road network passes through them. For Nottingham, less than 10\% of the flow on the unweighted network passes through trunk roads, but almost 25\% of the flow passes through tertiary roads (Figure \ref{fig:perc_person-km}).  -->

The results of routing potential cycling demand on the weighted and
unweighted networks are understandably quite different. From Figure
<a href="#fig:flowsfacetunweighted">3</a> we can see that trunk and
primary roads are the most efficient means of traversing the road
network of Manchester. Both of these road types are classified as
Primary A roads according to the UK Department for Transport’s road
classification (Table
<a href="#table:osmroadtypes"><strong>??</strong></a>), and are
therefore part of the Primary Route Network (PRN) (DfT 2012). The PRN
has the widest, most direct roads on the network, and carries most of
the through traffic. This includes freight, with all roads in the PRN
being required by law to provide unrestricted access to trucks up to 40
tonnes (DfT 2012).

We choose to avoid routing the potential cycling demand on Primary A
Roads for the following 2 reasons:

1.  **Logistical Difficulty**: Changes on these roads need to be agreed
    upon by all affected authorities (DfT 2012), which may prove to be
    difficult.
2.  **Low Traffic Neighborhoods (LTNs)**: The UK government is aiming to
    restrict access to motorized vehicles on residential roads to create
    LTNs (DfT 2020b). This is part of a policy to prevent automobile
    rat-running and make streets more accessible to cyclists and
    pedestrians. Under such a policy, Primary A roads would become even
    more essential for motorized traffic and it would be more difficult
    to reallocate road space on these roads to cyclists.

Figure <a href="#fig:flowsfacetweighted">4</a> shows that routing on the
weighted network significantly reduces flow on the trunk and primary
roads, but does not eliminate it completely. This is intentional, as the
impedance on these roads is only slightly higher than remaining road
types (See Table
<a href="#table:weightprofiles"><strong>??</strong></a>). Potential
cycling demand is only routed on these roads if there are no routes
through other roads that offer comparable directness.

Banning cycling flow completely on trunk and primary roads may result in
excessively circuitous paths, as seen in Figure
<a href="#fig:boxplotcircuity">5</a>. When routing using the *weighted*
weighting profile in Table
<a href="#table:weightprofiles"><strong>??</strong></a>, we see that
shortest paths increase by less than 5% on average from unweighted
shortest paths, with the largest increases still below 30%. When routing
on primary and trunk roads is banned (*weighted\_2* profile in Table
<a href="#table:weightprofiles"><strong>??</strong></a>), the average
increase relative to unweighted shortest paths rises to 10%, with
certain locations experiencing more significant negative effects on
accessibility.

<div class="figure">

<img src="data/Manchester/Plots/boxplot_weighted_unweighted_distances.png" alt="Effect of Banning Cyclists from Trunk and Primary Roads for all OD Pairs (Manchester)" width="35%" />

<p class="caption">

Figure 5: Effect of Banning Cyclists from Trunk and Primary Roads for
all OD Pairs (Manchester)

</p>

</div>

Given that cyclists will only deviate from shortest paths by a certain
amount to access better cycling infrastructure (as explained in Section
<a href="#introduction">2</a>), allowing flow on some stretches of trunk
and primary roads is necessary to insure cycling uptake and equitable
access to cycling infrastructure. In its new vision for walking and
cycling, the Department for Transport acknowledges that minimal
segregated stretches of bicycle lanes on main roads will be necessary to
avoid circuitous cycling networks (DfT 2020b).

Weighting the road network also allows us to better utilize existing
cycling infrastructure, as can be seen by the higher flow on cycleways
in Figure <a href="#fig:flowsfacetweighted">4</a>. Again, the small
differences in impedance between cycleways and other road types mean
that cycleways that require significant deviation are not routed on.

It should be reiterated that the weighting profile used for routing has
been developed for the purposes of this study. It creates a hierarchy of
road preference that is grounded in cyclist preferences and government
plans to create LTNs. Sensitivity analysis should be done to determine
an optimal weighting profile, but given the variation in city road
networks<!-- (Figure \ref{fig:perc_person-km}) -->, these would probably
require calibration to the specific city. More accurate routing could be
carried out given the availability of road-level data. In such cases we
would add additional impedance to specific roads, giving more useful
routing results than the current methodology which considers all roads
of the same type to be equivalent.

One use-case of such granular data would be to identify roads that serve
schools. The Department of Transport notes that the number of school
children being driven to school has trebled over the past 40 years (DfT
2020b), and so having cycling infrastructure serving schools is key to
achieving the government target of getting more children to cycle. This
would not be difficult, as over 75% of children in the UK live within a
15 minute cycle from their school (DfT 2020a). Goodman et al. (2019)
show that if dutch levels of cycling were achieved in the UK, the % of
children cycling to school could increase from 1.8% to 41%. In their
typology of cyclists, Dill and McNeil (2013) found that a majority of
people who say they would never cycle had never cycled to school,
whereas confident cyclists were those most likely to have cycled to
school. Getting people to cycle from a young age is therefore key to
achieving societal change in commuting habits.

# Community Detection

One of the main aims of this research is to incorporate egalitarian
principles by fairly distributing investments in cycling infrastructure.
One way of quantifying this is to split up the city into smaller
geospatial areas and target equal investment in each of those areas.
Community detection offers us a way to delineate such a split; cyclists
are limited in their commuting distance (see Figure
<a href="#fig:cyclinghistmanc">6</a>), and so trip attractors are more
likely to have a local catchment area of cyclists.

<div class="figure">

<img src="data/Manchester/Plots/histogram_distance_cycling.png" alt="Cycling Commuting Distance - Manchester (2011 Census Data)" width="30%" />

<p class="caption">

Figure 6: Cycling Commuting Distance - Manchester (2011 Census Data)

</p>

</div>

In our case, the network is the city; the nodes are the
population-weighted MSOA centroids and the links connecting each MSOA
pair are weighted by the potential cycling demand between them. The
Louvian method (Blondel et al. 2008) is used to separate MSOAs into
communities. Potential cycling demand is used since we assume that this
is what the cycling demand will be once the cycling infrastructure is
added. To assign road links to communities, the following steps are
carried out:

<!-- 1. Create links between MSOA centroids and weigh these links by potential cycling demand between them.
2. Use Louvian method to determine optimal number of communities and assign each MSOA centroid to a community.
3. Assign each road link to the same community as the closest MSOA centroid to it. -->

``` r
1. Create links between MSOA centroids and weigh these links by potential cycling demand between them.
2. Use Louvian method to determine optimal number of communities and assign each MSOA centroid to a community.
3. Assign each road link to the same community as the closest MSOA centroid to it.
```

The results show that Manchester can be split into four large
communities and one small one (Figure
<a href="#fig:communitiesmanchester">7</a>).

<div class="figure">

<img src="data/Manchester/Plots/communities_alternative_Manchester.png" alt="Communities Based on Potential Cycling Demand (Manchester)" width="75%" />

<p class="caption">

Figure 7: Communities Based on Potential Cycling Demand (Manchester)

</p>

</div>

# Road Segment Prioritization

After routing the potential cycling demand onto the road network using
weighted shortest paths, we have estimates for the cumulative potential
cycling demand passing through all road segments. This cumulative demand
(referred to as *flow*) is then used as a basis for determining where
best to invest in segregated cycling infrastructure. In doing so, we
must account for the motivations and deterrents for cycling identified
in Section <a href="#introduction">2</a>, namely direct and well
connected routes.

For this purpose, two algorithms are proposed. Both utilize existing
infrastructure from the beginning and allow us to compare a solution
that focuses on utilitarianism to one that focuses on egalitarianism. In
both algorithms, links are selected iteratively and the iteration at
which each link is added to the solution is recorded. Investments in
cycling infrastructure can be limited by budget constraints, so it can
be useful to see where best to allocate a defined length of segregated
infrastructure.

## Algorithm 1: Utilitarian Expansion

<!-- 1. Identify all links that have segregated cycling infrastructure and add them to the initial solution
2. Identify all links that neighbor links in the current solution
3. Select neighboring link with highest flow and add it to the solution
4. Repeat steps 2 \& 3 until all flow is satisfied or investment threshold is met -->

``` r
1. Identify all links that have segregated cycling infrastructure and add them to the 
   initial solution
2. Identify all links that neighbor links in the current solution
3. Select neighboring link with highest flow and add it to the solution
4. Repeat steps 2 and 3 until all flow is satisfied or investment threshold is met
```

This algorithm ensures that the resulting network is connected. It also
satisfies the directness criteria, since links on the weighted shortest
paths are those that have the highest flow passing through them (this is
a result of the routing in Section <a href="#introduction">2</a>.

## Algorithm 2: Egalitarian Expansion (Focus on Fair Distribution of Resources)

The first algorithm focuses on connectivity and directness, but not on
fairly distributing investment. The latter is not a requirement for
increasing cycling uptake, but it is fundamental for spatial equity, as
explained in Section <a href="#introduction">2</a>. This algorithm
incorporates the ideal of fair distribution by using community detection
to partition the road network.

The algorithm uses the following logic to ensure fair distribution
between communities:

<!-- 1. Identify all links that have segregated cycling infrastructure and add them to the initial solution
2. Identify all links that neighbor links in the current solution
3. Select *from each community* one neighboring link with highest flow and add it to the solution
4. If there are no more neighboring links in a community, select the link with the highest flow in that community, regardless of connectivity, and add it to the solution
5. Repeat steps 2, 3 \& 4 until all flow is satisfied or investment threshold is met -->

``` r
1. Identify all links that have segregated cycling infrastructure and add them to the initial 
   solution
2. Identify all links that neighbor links in the current solution
3. Select from each community one neighboring link with highest flow and add it to the 
   solution
4. If there are no more neighboring links in a community, select the link with the highest 
   flow in that community, regardless of connectivity, and add it to the solution
5. Repeat steps 2, 3 and 4 until all flow is satisfied or investment threshold is met
```

Even though we may end up with a more disconnected network, we will have
separate connected networks in each community. Given that communities
are defined by having more internal flow than external flow, this is a
satisfactory solution.

The results of the community detection are used to evaluate the
algorithms. This is done by looking at the *person-km satisfied* as
cycling infrastructure is added. Person-km is a measure of the total km
cycled on a road segment, so it is the product of the number of
potential commuters cycling on that road segment (\(flow\)) and the
length of the segment in km (\(l\)). For each road segment, the
person-km is equal to \(flow * l\). In the case of Manchester, Table
<a href="#tab:personkmtable">1</a> shows that almost half of the
person-km is in community 1 , while only 0.5% of total person-km on the
network is in community 5.

| Community | Person-Km (Total) | Person-Km (%) |
| :-------- | :---------------- | ------------: |
| 1         | 284,458           |          44.4 |
| 2         | 163,877           |          25.6 |
| 3         | 79,218            |          12.4 |
| 4         | 109,635           |          17.1 |
| 5         | 3,317             |           0.5 |

Table 1: Total Person-Km in Different Communities (Manchester)

Looking at the person-km satisfied (Figure
<a href="#fig:growthtotal">8</a>), we see that the incremental addition
of cycling infrastructure is better distributed between communities
using Algorithm 2; equal distribution of investment results in the gain
in % of person km satisfied in each community being inversely correlated
with the size of the community. In addition, we find that the
restrictions imposed by Algorithm 2 on the network expansion do not seem
to have a noticeable effect on the city-wide % of person-km satisfied.
Comparing both algorithms, we can see that Algorithm 1 provides only
marginally quicker city-wide gains than Algorithm 2.

<div class="figure">

<img src="data/Manchester/Plots/Growth_Results/growth_utilitarian_satisfied_km_both_flow_column.png" alt="Comparing Overall (Dashed) and Community Level Person-Km Satisfied (Manchester)" width="45%" /><img src="data/Manchester/Plots/Growth_Results/growth_egalitarian_satisfied_km_both_flow_column.png" alt="Comparing Overall (Dashed) and Community Level Person-Km Satisfied (Manchester)" width="45%" />

<p class="caption">

Figure 8: Comparing Overall (Dashed) and Community Level Person-Km
Satisfied (Manchester)

</p>

</div>

Figure <a href="#fig:growth3MapandBar">9</a> gives us a geographic
representation of the results from Algorithm 2; it shows when each link
was added to the solution (first 100km, second 100km, etc). We can see
that, generally, road segments around cycling infrastructure are
prioritized, except for those neighboring cycling infrastructure on the
very periphery. The first 100km is also spatially distributed across the
city, with no apparent bias towards a particular area.

It is also important to understand how the different highway types
contribute to the proposed network. Figure
<a href="#fig:growth3MapandBar">9</a> shows that most of the flow will
be on residential and tertiary roads, as expected from the weighting
profile defined in Table
<a href="#table:weightprofiles"><strong>??</strong></a>.

<div class="figure">

<img src="data/Manchester/Plots/Growth_Results/growth_egalitarian_priority_all_FLOW.png" alt="Results of Alg. 2 (Manchester)" width="45%" /><img src="data/Manchester/Plots/Growth_Results/growth_egalitarian_investment_highways_flow.png" alt="Results of Alg. 2 (Manchester)" width="45%" />

<p class="caption">

Figure 9: Results of Alg. 2 (Manchester)

</p>

</div>

## Connectivity

Existing cycling infrastructure is made up of many disconnected
components. Both Algorithm 1 and 2 start with all existing segregated
cycling infrastructure and aim to create an efficient, connected
network. Figure <a href="#fig:componentsandGCC">10</a> shows that both
algorithms gradually reduce the number of components as more
infrastructure is added, but Algorithm 2 is able to provide better
connectivity with less investment.

Consistent growth can also be seen for the size of the Largest Connected
Component in the proposed bicycle network (Figure
<a href="#fig:componentsandGCC">10</a>). Here however, we find that
there is little difference between both Algorithms.

<div class="figure">

<img src="data/Manchester/Plots/Growth_Results/growth_util_egal_components_number_comparisonManchester.png" alt="Network Characteristics" width="45%" /><img src="data/Manchester/Plots/Growth_Results/growth_util_egal_components_gcc_comparisonManchester.png" alt="Network Characteristics" width="45%" />

<p class="caption">

Figure 10: Network Characteristics

</p>

</div>

# Overarching Policies

While segregated, connected, and direct cycling infrastructure is key to
achieving high levels of cycling, research has shown that it cannot
exist in a vacuum. Wardman, Tight, and Page (2007) developed a mode
choice model for the UK and their results showed that improved cycling
infrastructure on its own only had modest impacts on mode shift, and
even the unlikely scenario of all urban routes being serviced by
segregated bike lanes was forecast to increase cycling mode share by
only 3%. However, cities that invest in more comprehensive cycling
projects show a more significant increase in the number of cyclists as
well as the cycling mode share (Pucher, Dill, and Handy 2010). These
cities do not just focus on infrastructure, but on general policies as
well as restricting car use. Evaluation of policies in Denmark and
Germany and the Netherlands has shown that their high cycling mode share
is down to a broader set of policies that also include traffic calming,
cycling rights of way, bike parking, integration with the public
transport network, and making driving cars both expensive and
inconvenient (Pucher and Buehler 2008). While these policies are outside
the scope of this research, it is important to recognize their key role
in bringing about an increase in levels of cycling.

# Disussion and conclusions

This paper provides a methodology for prioritizing road segments for
investments in cycling infrastructure, with the output being a proposed
cycling network for the city under study. The approach aims to respect
both the needs of the users and the ambitions of stakeholders working at
local/regional levels. The results, primarily detailed route network
maps based on current travel behaviour derived from origin-destination
data, can be a starting point for introducing a direct, connected, and
low-stress network for any city by leveraging available open data. The
only data necessary for reproducing it is the road network (from OSM),
its topography (from satellite imagery), and commuter data (from the
national census)\[6\].

The approach is not without limitations. The level of detail is only as
good as the granularity of the available data (in this case relatively
coarse zones). Iacono, Krizek, and El-Geneidy (2010) note that such
large travel zones are not ideal for understanding route choice
behaviour of cyclists and pedestrians. They also give rise to an
\`ecological fallacy’ whereby average characteristics are assumed to
apply to all residents of the aggregated geographical area, suggesting a
need for applying the methods to more granular origin-destination data
(and for governments and other data-collecting organisations to make
origin-destination data more readily available).

A core part of the methodology is determining where there is high
potential for cycling, and using this as a basis for recommendations on
road space reallocation in order to unlock potential cycling demand. A
routing engine was used to study the effects of limiting access on
different road types, and it was found that reducing cyclist flow on
roads with high through-traffic resulted in acceptable increases in
commuting distances. As a result, a hierarchy of road preference was
used to route potential cycling demand. Algorithms were developed to
determine where investments in cycling infrastructure should be
prioritized. These algorithms, based on connectivity and egalitarian
principles of resource distribution, ensured that whatever the level of
investment, the resulting cycling network would improve connectivity of
existing cycling infrastructure.

The methods can support the ongoing shift in transport planning towards
active transport that is being promoted by the UK government and other
authorities at city, regional and national levels worldwide. The success
of such a shift depends on the appeal of the cycling network for
prospective cyclists, a fact that was used as the basis for the
methodology outlined here.

<!-- I think it would be good to say how others could reproduce the methods in other cities (RL) -->

<!-- (HM) Answer: Done. I added a footnote to the first paragraph in the conclusion linking to the github repo -->

<!-- There should also be links to the literature. -->

<!-- (HM) Answer: There are links to the literature at the end of each thematic section (Calculating Potential Cycling Demand / Routing / Road Segment Prioritization). There is a discussion paragraph in each of them. What additional links are necessary here? -->

# References

<!-- to fix indentation: https://github.com/crsh/papaja/issues/37#issuecomment-104185288 -->

<div id="refs" class="references">

<div id="ref-akbarzadeh2018designing">

Akbarzadeh, Meisam, Syed Sina Mohri, and Ehsan Yazdian. 2018. “Designing
Bike Networks Using the Concept of Network Clusters.” *Applied Network
Science* 3 (1): 12.

</div>

<div id="ref-aldred2019impacts">

Aldred, Rachel, Joseph Croft, and Anna Goodman. 2019. “Impacts of an
Active Travel Intervention with a Cycling Focus in a Suburban Context:
One-Year Findings from an Evaluation of London’s in-Progress
Mini-Hollands Programme.” *Transportation Research Part A: Policy and
Practice* 123: 147–69.

</div>

<div id="ref-bao2017planning">

Bao, Jie, Tianfu He, Sijie Ruan, Yanhua Li, and Yu Zheng. 2017.
“Planning Bike Lanes Based on Sharing-Bikes’ Trajectories.” In
*Proceedings of the 23rd Acm Sigkdd International Conference on
Knowledge Discovery and Data Mining*, 1377–86.

</div>

<div id="ref-blondel2008fast">

Blondel, Vincent D, Jean-Loup Guillaume, Renaud Lambiotte, and Etienne
Lefebvre. 2008. “Fast Unfolding of Communities in Large Networks.”
*Journal of Statistical Mechanics: Theory and Experiment* 2008 (10):
P10008.

</div>

<div id="ref-brand_climate_2020">

Brand, Christian, Evi Dons, Esther Anaya-Boig, Ione Avila-Palencia, Anna
Clark, Audrey de Nazelle, Mireia Gascon, Mailin Gaupp-Berghausen, Regine
Gerike, and Thomas Gotschi. 2020. “The Climate Change Mitigation Effects
of Active Travel.” *Preprint: Researchsquare.com*.

</div>

<div id="ref-broach2011bicycle">

Broach, Joseph, John Gliebe, and Jennifer Dill. 2011. “Bicycle Route
Choice Model Developed Using Revealed Preference Gps Data.” In *90th
Annual Meeting of the Transportation Research Board, Washington, Dc*.

</div>

<div id="ref-buehler2016bikeway">

Buehler, Ralph, and Jennifer Dill. 2016. “Bikeway Networks: A Review of
Effects on Cycling.” *Transport Reviews* 36 (1): 9–27.

</div>

<div id="ref-caulfield2012determining">

Caulfield, Brian, Elaine Brick, and Orla Thérèse McCarthy. 2012.
“Determining Bicycle Infrastructure Preferences–a Case Study of
Dublin.” *Transportation Research Part D: Transport and Environment* 17
(5): 413–17.

</div>

<div id="ref-celis2017association">

Celis-Morales, Carlos A, Donald M Lyall, Paul Welsh, Jana Anderson,
Lewis Steell, Yibing Guo, Reno Maldonado, et al. 2017. “Association
Between Active Commuting and Incident Cardiovascular Disease, Cancer,
and Mortality: Prospective Cohort Study.” *Bmj* 357: j1456.

</div>

<div id="ref-crane2017longitudinal">

Crane, Melanie, Chris Rissel, Chris Standen, Adrian Ellison, Richard
Ellison, Li Ming Wen, and Stephen Greaves. 2017. “Longitudinal
Evaluation of Travel and Health Outcomes in Relation to New Bicycle
Infrastructure, Sydney, Australia.” *Journal of Transport & Health* 6:
386–95.

</div>

<div id="ref-department2012guidance">

DfT. 2012. “Guidance on Road Classification and the Primary Route
Network.” Department of Transport of Britain.

</div>

<div id="ref-departmentcycleinfradesign2020">

———. 2020a. “Cycling Infrastructure Design.”

</div>

<div id="ref-departmentgearchange2020">

———. 2020b. “Gear Change: A Bold Vision for Cycling and Walking.”

</div>

<div id="ref-dill2013four">

Dill, Jennifer, and Nathan McNeil. 2013. “Four Types of Cyclists?
Examination of Typology for Better Understanding of Bicycling Behavior
and Potential.” *Transportation Research Record* 2387 (1): 129–38.

</div>

<div id="ref-duthie2014optimization">

Duthie, Jennifer, and Avinash Unnikrishnan. 2014. “Optimization
Framework for Bicycle Network Design.” *Journal of Transportation
Engineering* 140 (7): 04014028.

</div>

<div id="ref-goodman2019scenarios">

Goodman, Anna, Ilan Fridman Rojas, James Woodcock, Rachel Aldred,
Nikolai Berkoff, Malcolm Morgan, Ali Abbas, and Robin Lovelace. 2019.
“Scenarios of Cycling to School in England, and Associated Health and
Carbon Impacts: Application of the ‘Propensity to Cycle Tool’.” *Journal
of Transport & Health* 12: 263–78.

</div>

<div id="ref-goodman2014new">

Goodman, Anna, Shannon Sahlqvist, David Ogilvie, and iConnect
Consortium. 2014. “New Walking and Cycling Routes and Increased Physical
Activity: One-and 2-Year Findings from the Uk iConnect Study.” *American
Journal of Public Health* 104 (9): e38–e46.

</div>

<div id="ref-iacono2010measuring">

Iacono, Michael, Kevin J Krizek, and Ahmed El-Geneidy. 2010. “Measuring
Non-Motorized Accessibility: Issues, Alternatives, and Execution.”
*Journal of Transport Geography* 18 (1): 133–40.

</div>

<div id="ref-jafino2020transport">

Jafino, Bramka Arga, Jan Kwakkel, and Alexander Verbraeck. 2020.
“Transport Network Criticality Metrics: A Comparative Analysis and a
Guideline for Selection.” *Transport Reviews* 40 (2): 241–64.

</div>

<div id="ref-jarrett2012effect">

Jarrett, James, James Woodcock, Ulla K Griffiths, Zaid Chalabi, Phil
Edwards, Ian Roberts, and Andy Haines. 2012. “Effect of Increasing
Active Travel in Urban England and Wales on Costs to the National Health
Service.” *The Lancet* 379 (9832): 2198–2205.

</div>

<div id="ref-kohl2012pandemic">

Kohl 3rd, Harold W, Cora Lynn Craig, Estelle Victoria Lambert, Shigeru
Inoue, Jasem Ramadan Alkandari, Grit Leetongin, Sonja Kahlmeier, Lancet
Physical Activity Series Working Group, and others. 2012. “The Pandemic
of Physical Inactivity: Global Action for Public Health.” *The Lancet*
380 (9838): 294–305.

</div>

<div id="ref-lovelace2017propensity">

Lovelace, Robin, Anna Goodman, Rachel Aldred, Nikolai Berkoff, Ali
Abbas, and James Woodcock. 2017. “The Propensity to Cycle Tool: An Open
Source Online System for Sustainable Transport Planning.” *Journal of
Transport and Land Use* 10 (1): 505–28.

</div>

<div id="ref-lucas2016method">

Lucas, Karen, Bert Van Wee, and Kees Maat. 2016. “A Method to Evaluate
Equitable Accessibility: Combining Ethical Theories and
Accessibility-Based Approaches.” *Transportation* 43 (3): 473–90.

</div>

<div id="ref-marques2015infrastructure">

Marqués, R, V Hernández-Herrador, M Calvo-Salazar, and JA
García-Cebrián. 2015. “How Infrastructure Can Promote Cycling in
Cities: Lessons from Seville.” *Research in Transportation Economics*
53: 31–44.

</div>

<div id="ref-mauttone2017bicycle">

Mauttone, Antonio, Gonzalo Mercadante, María Rabaza, and Fernanda
Toledo. 2017. “Bicycle Network Design: Model and Solution Algorithm.”
*Transportation Research Procedia* 27: 969–76.

</div>

<div id="ref-mesbah2012bilevel">

Mesbah, Mahmoud, Russell Thompson, and Sara Moridpour. 2012. “Bilevel
Optimization Approach to Design of Network of Bike Lanes.”
*Transportation Research Record* 2284 (1): 21–28.

</div>

<div id="ref-nahmias2017integrating">

Nahmias-Biran, Bat-hen, Karel Martens, and Yoram Shiftan. 2017.
“Integrating Equity in Transportation Project Assessment: A
Philosophical Exploration and Its Practical Implications.” *Transport
Reviews* 37 (2): 192–210.

</div>

<div id="ref-natera2019data">

Natera, Luis, Federico Battiston, Gerardo Iñiguez, and Michael Szell.
2019. “Data-Driven Strategies for Optimal Bicycle Network Growth.”
*arXiv Preprint arXiv:1907.07080*.

</div>

<div id="ref-olmos2020data">

Olmos, Luis E, Maria Sol Tadeo, Dimitris Vlachogiannis, Fahad Alhasoun,
Xavier Espinet Alegre, Catalina Ochoa, Felipe Targa, and Marta C
González. 2020. “A Data Science Framework for Planning the Growth of
Bicycle Infrastructures.” *Transportation Research Part C: Emerging
Technologies* 115: 102640.

</div>

<div id="ref-ONS2011flowdata">

ONS. 2011. “2011 Census: Special Workplace Statistics (United Kingdom).”

</div>

<div id="ref-ofn2018population">

———. 2018. “Population Estimates for the Uk, England and Wales, Scotland
and Northern Ireland: Mid-2017.” *Hampshire: Office for National
Statistics*.

</div>

<div id="ref-padgham2019dodgr">

Padgham, Mark. 2019. “Dodgr: An R Package for Network Flow Aggregation.”
*Transport Findings. Network Design Lab*.

</div>

<div id="ref-patterson2020associations">

Patterson, Richard, Jenna Panter, Eszter P Vamos, Steven Cummins,
Christopher Millett, and Anthony A Laverty. 2020. “Associations Between
Commute Mode and Cardiovascular Disease, Cancer, and All-Cause
Mortality, and Cancer Incidence, Using Linked Census Data over 25 Years
in England and Wales: A Cohort Study.” *The Lancet Planetary Health* 4
(5): e186–e194.

</div>

<div id="ref-pereira2017distributive">

Pereira, Rafael HM, Tim Schwanen, and David Banister. 2017.
“Distributive Justice and Equity in Transportation.” *Transport
Reviews* 37 (2): 170–91.

</div>

<div id="ref-pucher2008making">

Pucher, John, and Ralph Buehler. 2008. “Making Cycling Irresistible:
Lessons from the Netherlands, Denmark and Germany.” *Transport Reviews*
28 (4): 495–528.

</div>

<div id="ref-pucher2010infrastructure">

Pucher, John, Jennifer Dill, and Susan Handy. 2010. “Infrastructure,
Programs, and Policies to Increase Bicycling: An International Review.”
*Preventive Medicine* 50: S106–S125.

</div>

<div id="ref-schoner2014missing">

Schoner, Jessica E, and David M Levinson. 2014. “The Missing Link:
Bicycle Infrastructure Networks and Ridership in 74 Us Cities.”
*Transportation* 41 (6): 1187–1204.

</div>

<div id="ref-stinson2003commuter">

Stinson, Monique A, and Chandra R Bhat. 2003. “Commuter Bicyclist Route
Choice: Analysis Using a Stated Preference Survey.” *Transportation
Research Record* 1828 (1): 107–15.

</div>

<div id="ref-agreement2015paris">

UN. 2015. “Paris Agreement.” In *Report of the Conference of the Parties
to the United Nations Framework Convention on Climate Change (21st
Session, 2015: Paris). Retrived December*, 4:2017. HeinOnline.

</div>

<div id="ref-wardman2007factors">

Wardman, Mark, Miles Tight, and Matthew Page. 2007. “Factors Influencing
the Propensity to Cycle to Work.” *Transportation Research Part A:
Policy and Practice* 41 (4): 339–50.
<https://doi.org/10.1016/j.tra.2006.09.011>.

</div>

<div id="ref-winters2011motivators">

Winters, Meghan, Gavin Davidson, Diana Kao, and Kay Teschke. 2011.
“Motivators and Deterrents of Bicycling: Comparing Influences on
Decisions to Ride.” *Transportation* 38 (1): 153–68.

</div>

<div id="ref-winters2010far">

Winters, Meghan, Kay Teschke, Michael Grant, Eleanor M Setton, and
Michael Brauer. 2010. “How Far Out of the Way Will We Travel? Built
Environment Influences on Route Selection for Bicycle and Car Travel.”
*Transportation Research Record* 2190 (1): 1–10.

</div>

</div>

1.  *Segregated cycling infrastructure* refers to road space that is
    allocated to cyclists only, with physical separation to protect
    cyclists from other modes of transport.

2.  making an area’s bicycle network denser means adding more cycling
    routes in the area and thereby giving cyclists more route options

3.  *link* refers to a road segment throughout this research

4.  *flow* is used throughout this research to refer to the cycling
    demand when it is routed onto the road network. The flow on any road
    segment is the cumulative demand on it, resulting from cyclists
    commuting between various OD pairs

5.  The **dodgr** r package (Padgham 2019) is used to route cycling
    demand onto the road network. The package uses the OpenStreetMaps
    (OSM) road network and allows the user to assign weights to roads
    based on their type. The routing is done based on weighted shortest
    paths, with the distance along each road segment being divided by a
    factor to obtain the weighted distance for routing. It is more
    intuitive to multiply when weighting a network, but the dodgr
    package divides by numbers between 0 and 1, which achieves the same
    result. For the sake of reproducibility, we stick to the convention
    used in the package.

6.  The results are easily reproducible for all UK cities, and can also
    be reproduced for cities elsewhere given the availability of
    commuter data. Instructions for reproducing the results are detailed
    in this [Github
    repository](https://github.com/Hussein-Mahfouz/cycle-networks)
