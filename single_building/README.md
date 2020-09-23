# SHEMS
Smart home energy management system of a single building considering modulating heat pumps and photovoltaic systems
Explore the results interactively:   [![Binder](https://mybinder.org/badge_logo.svg)](https://mybinder.org/v2/gh/lilanger/SHEMS/master?filepath=single_building%2FSHEMS_visualization_Interactive_julia.ipynb)


<p align="center">
  <img src="pics\SHEMS_graph.png" width="400"/>
</p>

## Optimization models written in Julia JuMP
### 3 different objective functions:
>1) Minimize net profits and comfort violations (base)
>  ``SHEMS_optimizer.jl``
>2) Maximize self-consumption
> 	``SHEMS_optimizer_seco.jl``
>3) Maximize self-sufficiency
> 	``SHEMS_optimizer_sesu.jl``
  
  
### 4 technological configuration cases:
>Case 1 (base case)   
>Case 2 (no battery)   
>Case 3 (no compensation for grid feed-in)   
>Case 4 (no battery, no compensation for grid feed-in)   

### 2 function for the different run modes
>Run mode 1: Run the whole time interval in on optimization run     
>``yearly_SHEMS(h_start=1, h_end=8760, objective=1, case=1, costfactor=1.0, outputflag=true, bc_violations=79)``   
>Run mode 2: Run the time interval in a rolling horizon approach  (only cost-minimization)   
>``roll_SHEMS(h_start, h_end, h_predict, h_control, case=1, costfactor=1.0, outputflag=false)``   

## How to run the model:
1) Run the file ``run_SHEMS.jl``  
2) Choose the combination of:     
  >- objective function  
  >- technological configuration  
  >- run mode  

## Examples:
Run model with 
  1) cost minimization (base), both (base case), single run, whole year (1-8760h)   
  >``yearly_SHEMS()``   
  2) cost minimization (base), no battery (case 2), single run, whole year (1-8760h)   
  >``yearly_SHEMS(1, 8760, 1, 2)``   
  3) maximize self-sufficiency (objective 3), no battery (case 2), single run, 1-120h   
  >``yearly_SHEMS(1, 120, 3, 2)``    
  3) cost minimization, no battery (case 2), rolling horizon run with prediction horizon 36h + control horizon 24h, whole year
  >``roll_SHEMS(1, 8760, 36, 24, 2)``    
 
## Results .csv files in the result folder follow the name convention  
``results_$(h_predict)_$(h_control)_$(h_start)-$(h_end)_$(objective)_$(case)_$(costfactor).csv``
