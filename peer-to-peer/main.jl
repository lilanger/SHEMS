using JuMP, Cbc, CSV, DataFrames;
# for using the Gurobi solver (license needed)
using Gurobi
GUROBI_ENV = Gurobi.Env() # Gurobi academic license message only once

struct HeatPump
    rate_max::Float32
end

struct ThermalStorage
    volume::Float32
    loss::Float32
    t_supply::Float32
    soc_min::Float32
    soc_max::Float32
end

struct Battery
    eta::Float32
    soc_min::Float32
    soc_max::Float32
    rate_max::Float32
    loss::Float32
end

mutable struct SHEMS
    n_peers::Int16
    costfactor::Float32
    p_buy::Float32
    p_sell::Float32
    p_peer::Float32
    soc_b::Array{Float32,1}
    soc_fh::Array{Float32,1}
    soc_hw::Array{Float32,1}
    h_start::Int16
end

struct Model_SHEMS
    h_start::Int16
    h_end::Int16
    h_predict::Int16
    h_control::Int16
    big::Int16
    solver::String
    mip_gap::Float32
    output_flag::Bool
    presolve_flag::Int
end
