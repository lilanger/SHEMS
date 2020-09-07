# SHEMS
Smart home energy management system of a peer-to-peer network considering modulating heat pumps and photovoltaic systems
Explore the results interactively:   [![Binder](https://mybinder.org/badge_logo.svg)](https://mybinder.org/v2/gh/lilanger/SHEMS/master?filepath=single_building%2FSHEMS_visualization_Interactive_julia.ipynb)


<p align="center">
  <img src="pics\PEERS_graph.png" width="600"/>
</p>

## Optimization model written in Julia JuMP
>Minimize net profits and comfort violations (base)
>  ``SHEMS_optimizer_peer.jl''


## How to run the model:
1) Run the file ``run_SHEMS.jl``  
2) Choose the combination of:     
  >- time horizons
  >- # of peers
  >- tariff case
  using function roll_SHEMS(market_flag, n_peers, n_market, h_start, h_end, h_predict, h_control, case)

## Examples:
Run model with 
  1) whole year (1-8760h), prediction horizon 36h, control horizon 12h, 3 peers, case 1 (current regime, with FiT)
  >``roll_SHEMS(1, 3, 1, 1, 8760, 36, 12, 1)
  2) cost minimization (base), no battery (case 2), single run, whole year (1-8760h)   
  >``yearly_SHEMS(1, 8760, 1, 2)``   
  3) maximize self-sufficiency (objective 3), no battery (case 2), single run, 1-120h   
  >``yearly_SHEMS(1, 120, 3, 2)``    
  3) cost minimization, no battery (case 2), rolling horizon run with prediction horizon 36h + control horizon 24h, whole year
  >``roll_SHEMS(1, 8760, 36, 24, 2)``    
 
## Results .csv files in the result folder follow the name convention  
``$(date)_results_$(h_predict)_$(h_control)_$(h_start)-$(h_end)_$(objective)_$(case)_$(costfactor).csv``
