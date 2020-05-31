# SHEMS
Smart home energy management system of a single building with PV and a variable-speed air-source heat pump

<p align="center">
  <img src="pics\SHEMS_graph.png" width="600"/>
</p>

### Optimization models written in Julia JuMP
3 different objective functions:
>1) Minimize net profits and comfort violations
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
>``yearly_SHEMS(h_start, h_end, objective, case, costfactor, outputflag, bc_violations)``   
>Run mode 2: Run the time interval in a rolling horizon approach     
>``roll_SHEMS(h_start, h_end, h_predict, h_control, costfactor, outputflag, case)``   

## How to run the model:
1) Run the .jl-file ``run_SHEMS.jl``  
2) Choose the combination of:     
  >- objective function  
  >- technological configuration  
  >- run mode  

