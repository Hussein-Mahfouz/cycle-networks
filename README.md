Road Segment Prioritization for Bicycle Infrastructure
================
2020-10-30

# 1 Ideas and discussion

# 2 Road Segment Prioritization for Bicycle Infrastructure

## 2.1 Missing Data

There are a couple of files that cannot be synced to github due to their
size. These files are neseccary for the scripts to run. Below are links
to where you can download them, and instructions on where to place them
in the repo file structure

Flow Data (2011 Census Origin-Destination Data):

-   Source: <https://www.nomisweb.co.uk/census/2011/bulk/rOD1> —&gt;
    Choose File **“WU03EW”**
-   Location in Repo: data-raw/flow\_data.csv

Middle Layer Super Output Areas (December 2011) Boundaries:

-   Source:
    <http://geoportal.statistics.gov.uk/datasets/826dc85fb600440889480f4d9dbb1a24_0>
-   Location in Repo: data-raw/MSOA\_2011\_Boundaries/
    *A**d**d**f**i**l**e**s**h**e**r**e*

------------------------------------------------------------------------

## 2.2 Scripts

The scripts should be run in the order they are numbered in (and listed
in here). The only exception is \_x\_dodgr\_weighting\_profiles.R.

Check the readme
[here](https://github.com/Hussein-Mahfouz/Bicycle-Network-Optimization)
for detailed info on each script

<!-- Keywords -->
<!-- ======== -->
<!-- Highlights -->
<!-- ======== -->

# 3 Introduction

Intro ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod
tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim
veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea
commodo consequat. Duis aute irure dolor in reprehenderit in voluptate
velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint
occaecat cupidatat non proident, sunt in culpa qui officia deserunt
mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur
adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore
magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco
laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor
in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla
pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa
qui officia deserunt mollit anim id est laborum.Lorem ipsum dolor sit
amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut
labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud
exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
Duis aute irure dolor in reprehenderit in voluptate velit esse cillum
dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non
proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

and these will be the conclusions

# 4 Background

## 4.1 What Affects the Decision To Cycle

Segregated cycling infrastructure has been shown to increase cycling
uptake (Aldred, Croft, and Goodman 2019; Goodman et al. 2014; Marqués et
al. 2015), with the separation from motorized vehicles being key
(Winters et al. 2011). Revealed preference of cyclists shows that they
are willing to deviate from the most efficient routes in order to
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
positively impact cycling rates, density of the cycling network is also
vital (Schoner and Levinson 2014).

## 4.2 Planning Cycling Networks

*Optimization* techniques have been used to propose improvements to
cycling networks. Mesbah, Thompson, and Moridpour (2012) propose a
bi-level formulation to optimize allocation of cycling lanes to the
network without exceeding a set budget. The upper level is the proposed
interventions and the lower level is the route choices made by users in
reaction to changes in the network. The problem accounts for the effect
of cycling lanes on car traffic, and attempts to maximize utilization of
said lanes with minimal impact on car travel times. To improve cohesion
of the suggested network, a constraint is added so that each link with a
bike lane should be connected to at least one destination. Car usage is
not considered by Mauttone et al. (2017), who develop an optimization
framework that aims to minimize the total user cost of cycling on the
network. The aggregate flow on links is obtained by using shortest paths
to route existing cycling demand onto the road network, and the solution
is a proposed set of links where cycling infrastructure should be added
in order to minimize the overall travel cost of cyclists across the
network. The cost of traversing a link is given as a function of its
length and whether or not it has cycling infrastructure, and a
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
filter out the links based on the aggregate flow passing through them.
They vary the flow threshold for filtering to identify the minimum flow
at which the whole city is connected by a giant component. The results
show a cycling network that connects the entire city, and subtracting
links intersecting with current cycling infrastructure identifies links
proposed for intervention.

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
highest benefit/cost ratio in each cluster is selected, and the network
is grown by adding neighboring links to the solution until a budget
limit is met. The benefit is the flow on the link, and each link is
assigned a cost based on current road conditions.

## 4.3 Underlying Ethical Principles

The methodologies in Section
<a href="#planning-cycling-networks">4.2</a> are underpinned by
different ethical principles, even though these principles are not
explicitly acknowledged by the authors. This is important since
different ethical principles constitute different problem formulations
and targets. Broadly speaking, transport appraisal can be based on
either utilitarian or egalitarian principles. The former seeks to
maximize the overall benefit, while the latter is concerned with a fair
distribution of benefits (Jafino, Kwakkel, and Verbraeck 2020).
Nahmias-Biran, Martens, and Shiftan (2017) criticize the utilitarian
approach that has been historically popular in the evaluation of
transport investments, explaining how the maximization of overall
benefit fails to account for the distribution of that benefit among
communities or individuals. Lucas, Van Wee, and Maat (2016) explain how
transport studies have traditionally looked at the bigger picture
without studying the distribution of investments on the different parts
of the study area, and go on to propose an egalitarian approach that
ensures the dis-aggregation of transport policy benefits across the
study area. Pereira, Schwanen, and Banister (2017) also emphasize the
need for a more egalitarian approach to transport planning. They
highlight accessibility as a cornerstone of distributive justice, and
contend that policies should aim to distribute investments in a way that
minimizes spatial variations in accessibility. This research attempts to
provide a methodology that is grounded in egalitarian principles.
**Write some more here**

# 5 Data and Geographical Scale of Analysis

The analysis is heavily dependant on Origin-Destination census data
(commuter data). Commuter data in the UK is publicly available at the
Middle layer Super Output Area (MSOA) level; the average MSOA has a
population of 8209 (ONS 2018). Iacono, Krizek, and El-Geneidy (2010)
note that such large travel zones are not ideal for understanding route
choice behaviour of cyclists and pedestrians. They also give rise to an
\`ecological fallacy’ whereby average characteristics are assumed to
apply to all residents of the aggregated geographical area. Given that
more granular data is not publicly available, the study uses MSOA-level
commuter data. The methodology is however applicable to more granular
commuter data should it become available.

# 6 Calculating Potential Cycling Demand

The Propensity to Cycle Tool (PCT) (Lovelace et al. 2017) is used to
estimate the proportion of cyclists (**C**<sub>**p**</sub>) for each
MSOA pair should the government achieve its target of doubling cycling
by 2025. The PCT uses the following logistic regression model to
calculate **C**<sub>**p**</sub>:

where **d** and **s** are the distance and slope respectively for the OD
pair. The authors use square and square-root distance terms \`\`to
capture the non-linear impact of distance on the likelihood of cycling",
and interaction terms to capture the combined effect of slope and
distance (Lovelace et al. 2017).

Simini et al. (2012)

The potential demand calculations show that the current and potential
number of cyclists both follow a bell-shaped distribution, with the
number of trips peaking around the 3-5km commuting distance and then
going back down for longer distances (see Figure
<a href="#fig:potdemhistograms">6.1</a>.

<div class="figure">

<img src="data/Manchester/Plots/desire_facet_cycling.png" alt="Current and Potential Cycling Demand" width="80%" />
<p class="caption">
Figure 6.1: Current and Potential Cycling Demand
</p>

</div>

# 7 Routing

The next step is to route the potential cycling demand
(**C**<sub>**p**</sub>) between all OD pairs onto the road network.

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
    Transport, partially through the creation of LTNs (DfT 2020). This
    includes closing off residential streets to motorized traffic
3.  **Existing Cycling Infrastructure**: Utilizing existing cycling
    infrastructure makes economic sense, as small investments may lead
    to large connectivity gains as the disconnected cycling
    infrastructure gets joined together.

The weighting profiles are therefore adjusted to favor less-stressful
streets (based on information from Table ), and roads with existing
cycling infrastructure. This is also in line with the creation of LTNs,
as residential streets are those where motorized traffic is most likely
to be banned in the creation of LTNs.

# 8 Road Segment Prioritization

``` r
knitr::include_graphics(c(
  "data/Manchester/Plots/Growth_Results/growth_existing_infra_satisfied_km_all_flow_column.png",
  "data/Manchester/Plots/Growth_Results/growth_community_4_satisfied_km_all_flow_column.png"
))
```

<div class="figure">

<img src="data/Manchester/Plots/Growth_Results/growth_existing_infra_satisfied_km_all_flow_column.png" alt="teswt" width="48%" /><img src="data/Manchester/Plots/Growth_Results/growth_community_4_satisfied_km_all_flow_column.png" alt="teswt" width="48%" />
<p class="caption">
Figure 8.1: teswt
</p>

</div>

<!-- Todo: uncomment for final submission -->
<!-- \begin{figure} [h!] -->
<!-- \centering -->
<!-- \captionsetup{font=footnotesize,labelfont=footnotesize} % size of captions -->
<!-- \begin{subfigure}{.45\textwidth} -->
<!--   \centering -->
<!--   \includegraphics[width=1\linewidth]{data/Manchester/Plots/Growth_Results/growth_existing_infra_satisfied_km_all_flow_column.png} -->
<!--   \caption{Alg 1 (Utilitarian)} -->
<!--   \label{fig:growth_utilitarian_satisfied_all} -->
<!-- \end{subfigure} -->
<!-- \begin{subfigure}{.45\textwidth} -->
<!--   \centering -->
<!--   \includegraphics[width=1\linewidth]{data/Manchester/Plots/Growth_Results/growth_community_4_satisfied_km_all_flow_column.png} -->
<!--   \caption{Alg 2 (Egalitarian)} -->
<!--   \label{fig:growth_egalitarian_satisfied_all} -->
<!-- \end{subfigure} -->
<!-- \caption{Comparing Overall Person-Km Satisfied (Manchester)} -->
<!-- \label{fig:growth_existing_infra_satisfied} -->
<!-- \end{figure} -->

# 9 Overarching Policies

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

# 10 Conclusions

# References

<!-- to fix indentation: https://github.com/crsh/papaja/issues/37#issuecomment-104185288 -->
<div id="refs" class="references csl-bib-body hanging-indent">

<div id="ref-akbarzadeh2018designing" class="csl-entry">

Akbarzadeh, Meisam, Syed Sina Mohri, and Ehsan Yazdian. 2018. “Designing
Bike Networks Using the Concept of Network Clusters.” *Applied Network
Science* 3 (1): 12.

</div>

<div id="ref-aldred2019impacts" class="csl-entry">

Aldred, Rachel, Joseph Croft, and Anna Goodman. 2019. “Impacts of an
Active Travel Intervention with a Cycling Focus in a Suburban Context:
One-Year Findings from an Evaluation of London’s in-Progress
Mini-Hollands Programme.” *Transportation Research Part A: Policy and
Practice* 123: 147–69.

</div>

<div id="ref-bao2017planning" class="csl-entry">

Bao, Jie, Tianfu He, Sijie Ruan, Yanhua Li, and Yu Zheng. 2017.
“Planning Bike Lanes Based on Sharing-Bikes’ Trajectories.” In
*Proceedings of the 23rd ACM SIGKDD International Conference on
Knowledge Discovery and Data Mining*, 1377–86.

</div>

<div id="ref-blondel2008fast" class="csl-entry">

Blondel, Vincent D, Jean-Loup Guillaume, Renaud Lambiotte, and Etienne
Lefebvre. 2008. “Fast Unfolding of Communities in Large Networks.”
*Journal of Statistical Mechanics: Theory and Experiment* 2008 (10):
P10008.

</div>

<div id="ref-broach2011bicycle" class="csl-entry">

Broach, Joseph, John Gliebe, and Jennifer Dill. 2011. “Bicycle Route
Choice Model Developed Using Revealed Preference GPS Data.” In *90th
Annual Meeting of the Transportation Research Board, Washington, DC*.

</div>

<div id="ref-caulfield2012determining" class="csl-entry">

Caulfield, Brian, Elaine Brick, and Orla Thérèse McCarthy. 2012.
“Determining Bicycle Infrastructure Preferences–a Case Study of Dublin.”
*Transportation Research Part D: Transport and Environment* 17 (5):
413–17.

</div>

<div id="ref-crane2017longitudinal" class="csl-entry">

Crane, Melanie, Chris Rissel, Chris Standen, Adrian Ellison, Richard
Ellison, Li Ming Wen, and Stephen Greaves. 2017. “Longitudinal
Evaluation of Travel and Health Outcomes in Relation to New Bicycle
Infrastructure, Sydney, Australia.” *Journal of Transport & Health* 6:
386–95.

</div>

<div id="ref-departmentgearchange2020" class="csl-entry">

DfT. 2020. “Gear Change: A Bold Vision for Cycling and Walking.”

</div>

<div id="ref-dill2013four" class="csl-entry">

Dill, Jennifer, and Nathan McNeil. 2013. “Four Types of Cyclists?
Examination of Typology for Better Understanding of Bicycling Behavior
and Potential.” *Transportation Research Record* 2387 (1): 129–38.

</div>

<div id="ref-duthie2014optimization" class="csl-entry">

Duthie, Jennifer, and Avinash Unnikrishnan. 2014. “Optimization
Framework for Bicycle Network Design.” *Journal of Transportation
Engineering* 140 (7): 04014028.

</div>

<div id="ref-goodman2014new" class="csl-entry">

Goodman, Anna, Shannon Sahlqvist, David Ogilvie, and iConnect
Consortium. 2014. “New Walking and Cycling Routes and Increased Physical
Activity: One-and 2-Year Findings from the UK iConnect Study.” *American
Journal of Public Health* 104 (9): e38–46.

</div>

<div id="ref-iacono2010measuring" class="csl-entry">

Iacono, Michael, Kevin J Krizek, and Ahmed El-Geneidy. 2010. “Measuring
Non-Motorized Accessibility: Issues, Alternatives, and Execution.”
*Journal of Transport Geography* 18 (1): 133–40.

</div>

<div id="ref-jafino2020transport" class="csl-entry">

Jafino, Bramka Arga, Jan Kwakkel, and Alexander Verbraeck. 2020.
“Transport Network Criticality Metrics: A Comparative Analysis and a
Guideline for Selection.” *Transport Reviews* 40 (2): 241–64.

</div>

<div id="ref-lovelace2017propensity" class="csl-entry">

Lovelace, Robin, Anna Goodman, Rachel Aldred, Nikolai Berkoff, Ali
Abbas, and James Woodcock. 2017. “The Propensity to Cycle Tool: An Open
Source Online System for Sustainable Transport Planning.” *Journal of
Transport and Land Use* 10 (1): 505–28.

</div>

<div id="ref-lucas2016method" class="csl-entry">

Lucas, Karen, Bert Van Wee, and Kees Maat. 2016. “A Method to Evaluate
Equitable Accessibility: Combining Ethical Theories and
Accessibility-Based Approaches.” *Transportation* 43 (3): 473–90.

</div>

<div id="ref-marques2015infrastructure" class="csl-entry">

Marqués, R, V Hernández-Herrador, M Calvo-Salazar, and JA
García-Cebrián. 2015. “How Infrastructure Can Promote Cycling in Cities:
Lessons from Seville.” *Research in Transportation Economics* 53: 31–44.

</div>

<div id="ref-mauttone2017bicycle" class="csl-entry">

Mauttone, Antonio, Gonzalo Mercadante, María Rabaza, and Fernanda
Toledo. 2017. “Bicycle Network Design: Model and Solution Algorithm.”
*Transportation Research Procedia* 27: 969–76.

</div>

<div id="ref-mesbah2012bilevel" class="csl-entry">

Mesbah, Mahmoud, Russell Thompson, and Sara Moridpour. 2012. “Bilevel
Optimization Approach to Design of Network of Bike Lanes.”
*Transportation Research Record* 2284 (1): 21–28.

</div>

<div id="ref-nahmias2017integrating" class="csl-entry">

Nahmias-Biran, Bat-hen, Karel Martens, and Yoram Shiftan. 2017.
“Integrating Equity in Transportation Project Assessment: A
Philosophical Exploration and Its Practical Implications.” *Transport
Reviews* 37 (2): 192–210.

</div>

<div id="ref-natera2019data" class="csl-entry">

Natera, Luis, Federico Battiston, Gerardo Iñiguez, and Michael Szell.
2019. “Data-Driven Strategies for Optimal Bicycle Network Growth.”
*arXiv Preprint arXiv:1907.07080*.

</div>

<div id="ref-olmos2020data" class="csl-entry">

Olmos, Luis E, Maria Sol Tadeo, Dimitris Vlachogiannis, Fahad Alhasoun,
Xavier Espinet Alegre, Catalina Ochoa, Felipe Targa, and Marta C
González. 2020. “A Data Science Framework for Planning the Growth of
Bicycle Infrastructures.” *Transportation Research Part C: Emerging
Technologies* 115: 102640.

</div>

<div id="ref-ofn2018population" class="csl-entry">

ONS. 2018. “Population Estimates for the UK, England and Wales, Scotland
and Northern Ireland: Mid-2017.” *Hampshire: Office for National
Statistics*.

</div>

<div id="ref-pereira2017distributive" class="csl-entry">

Pereira, Rafael HM, Tim Schwanen, and David Banister. 2017.
“Distributive Justice and Equity in Transportation.” *Transport Reviews*
37 (2): 170–91.

</div>

<div id="ref-pucher2008making" class="csl-entry">

Pucher, John, and Ralph Buehler. 2008. “Making Cycling Irresistible:
Lessons from the Netherlands, Denmark and Germany.” *Transport Reviews*
28 (4): 495–528.

</div>

<div id="ref-pucher2010infrastructure" class="csl-entry">

Pucher, John, Jennifer Dill, and Susan Handy. 2010. “Infrastructure,
Programs, and Policies to Increase Bicycling: An International Review.”
*Preventive Medicine* 50: S106–25.

</div>

<div id="ref-schoner2014missing" class="csl-entry">

Schoner, Jessica E, and David M Levinson. 2014. “The Missing Link:
Bicycle Infrastructure Networks and Ridership in 74 US Cities.”
*Transportation* 41 (6): 1187–1204.

</div>

<div id="ref-simini2012" class="csl-entry">

Simini, Filippo, Marta C González, Amos Maritan, and Albert-László
Barabási. 2012. “A Universal Model for Mobility and Migration Patterns.”
*Nature*, February, 812. <https://doi.org/10.1038/nature10856>.

</div>

<div id="ref-stinson2003commuter" class="csl-entry">

Stinson, Monique A, and Chandra R Bhat. 2003. “Commuter Bicyclist Route
Choice: Analysis Using a Stated Preference Survey.” *Transportation
Research Record* 1828 (1): 107–15.

</div>

<div id="ref-wardman2007factors" class="csl-entry">

Wardman, Mark, Miles Tight, and Matthew Page. 2007. “Factors Influencing
the Propensity to Cycle to Work.” *Transportation Research Part A:
Policy and Practice* 41 (4): 339–50.
<https://doi.org/10.1016/j.tra.2006.09.011>.

</div>

<div id="ref-winters2011motivators" class="csl-entry">

Winters, Meghan, Gavin Davidson, Diana Kao, and Kay Teschke. 2011.
“Motivators and Deterrents of Bicycling: Comparing Influences on
Decisions to Ride.” *Transportation* 38 (1): 153–68.

</div>

<div id="ref-winters2010far" class="csl-entry">

Winters, Meghan, Kay Teschke, Michael Grant, Eleanor M Setton, and
Michael Brauer. 2010. “How Far Out of the Way Will We Travel? Built
Environment Influences on Route Selection for Bicycle and Car Travel.”
*Transportation Research Record* 2190 (1): 1–10.

</div>

</div>
