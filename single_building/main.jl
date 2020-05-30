using JuMP, Gurobi, CSV, DataFrames;
GUROBI_ENV = Gurobi.Env() # Gurobi academic license message only once

struct HeatPump
    eta::Float32
    rate_max::Float32
end

struct ThermalStorage
    eta::Float32
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
    costfactor::Float32
    p_buy::Float32
    p_sell::Float32
    soc_b::Float32
    soc_fh::Float32
    soc_hw::Float32
    h_start::Int16
end

struct Model_SHEMS
    h_start::Int16
    h_end::Int16
    h_predict::Int16
    h_control::Int16
    big::Int16
    rolling_flag::Bool
    mip_gap::Float32
    output_flag::Bool
    presolve_flag::Int
end
