# SHEMS
Smart home energy management system of a single building with PV and a variable-speed air-source heat pump

<p align="center">
  <img src="pics\SHEMS_graph.png" width="600"/>
</p>

### Optimization models written in Julia JuMP
3 different objective functions:
>1) Minimize net profits and comfort violations (base)
>  ``SHEMS_optimizer.jl``
>2) Maximize self-consumption
> 	``SHEMS_optimizer_seco.jl``
>3) Maximize self-sufficiency
> 	``SHEMS_optimizer_sesu.jl``
  
  
### 3 technological configuration cases:
>Case 1 (base case)   
>Case 2 (no battery)   
>Case 3 (no compensation for grid feed-in)   
>Case 4 (no battery, no compensation for grid feed-in)   

### 2 function for the different run modes
>Run mode 1: Run the whole time interval in on optimization run     
>``yearly_SHEMS(h_start=1, h_end=8760, objective=1, case=1, costfactor=1.0, outputflag=true, bc_violations=79)``   
>Run mode 2: Run the time interval in a rolling horizon approach     
>``roll_SHEMS(h_start, h_end, h_predict, h_control, costfactor=1.0, outputflag=false, case=1)``   

## How to run the model:
1) Run the file ``run_SHEMS.jl``  
2) Choose the combination of:     
  >- objective function  
  >- technological configuration  
  >- run mode  

## Examples:
Run model with 
  1) cost minimization (base), both (base case), whole year   
  >``yearly_SHEMS()``   
  2) cost minimization (base), no battery (case 2), whole year   
  >``yearly_SHEMS()``   
 
