using JuMP, Gurobi, CSV, DataFrames;
GUROBI_ENV = Gurobi.Env() # Gurobi solver message only once

struct HeatPump
    eta::Float64
    rate_max::Float64
end

struct ThermalStorage
    eta::Float64
    vol::Float64
    loss::Float64
    t_supply::Float64
    soc_min::Float64
    soc_max::Float64
end

struct Battery
    eta::Float64
    soc_min::Float64
    soc_max::Float64
    rate_max::Float64
    loss::Float64
end

struct PeerMarket
    eta::Float64
    p_buy::Float64
    p_sell::Float64
    p_peer::Float64
end

mutable struct SHEMS
    n_peers::Int
    h_start::Int
    h_end::Int
    h_predict::Int
    h_control::Int
    soc_b::AbstractArray
    soc_fh::AbstractArray
    soc_hw::AbstractArray
end

struct Model_SHEMS
    mip_gap::Float64
    output_flag::Bool
    presolve_flag::Bool
end

function COPcalc(ts::ThermalStorage, t_outside)
    #Calculate coefficients of performance for every time period (1:h_predict)___________________________________________
    return cop = max.((5.8*ones(size(t_outside,1))) -(1. /14) * abs.((ts.t_supply*ones(size(t_outside,1))) -t_outside), 0);
end
