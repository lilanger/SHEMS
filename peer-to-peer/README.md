# SHEMS
Smart home energy management system of a peer-to-peer network considering modulating heat pumps and photovoltaic systems
Explore the results interactively:   [![Binder](https://mybinder.org/badge_logo.svg)](https://mybinder.org/v2/gh/lilanger/SHEMS/master?urlpath=https%3A%2F%2Fgithub.com%2Flilanger%2FSHEMS%2Fblob%2Fmaster%2Fpeer-to-peer%2FSHEMS_visualization_Interactive_julia.ipynb)


<p align="center">
  <img src="pics\PEERS_graph.png" width="600"/>
</p>

## Optimization model written in Julia JuMP
>Minimize net profits and comfort violations (base)
>  ``SHEMS_optimizer_peer.jl''


## How to run the model:
1) Run the file ``run_SHEMS.jl``  
2) Choose the combination of:     
  - time horizons
  - number  of peers
  - tariff case
  
  using function roll_SHEMS(market_flag, n_peers, n_market, h_start, h_end, h_predict, h_control, case)

## Examples:
Run model with 
  - whole year (1-8760h), prediction horizon 36h, control horizon 12h, 3 peers, case 1 (current regime, with FiT)
  >``roll_SHEMS(1, 3, 1, 1, 8760, 36, 12, 1)``

 
## Results .csv files in the result folder follow the name convention  
``$(date)_results_$(h_predict)_$(h_control)_$(h_start)-$(h_end)_$(market_flag)_$(n_peers)_$(case).csv``
