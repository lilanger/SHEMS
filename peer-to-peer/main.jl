using JuMP, Cbc, CSV, DataFrames;
# for using the Gurobi solver (license needed)
using Gurobi
GUROBI_ENV = Gurobi.Env() # Gurobi academic license message only once

struct HeatPump
    rate_max::Float32
end

struct PV
    eta_i::Float32
end

struct ThermalStorage
    volume::Float32
    loss::Float32
    t_supply::Float32
    soc_min::Float32
    soc_max::Float32
end

struct Battery
    eta_b::Float32
    soc_min::Float32
    soc_max::Float32
    rate_max::Float32
    loss::Float32
end

mutable struct SHEMS
    market_flag::Bool
    n_peers::Int16
    n_market::Int16
    soc_b::Array{Float32,1}
    soc_fh::Array{Float32,1}
    soc_hw::Array{Float32,1}
    h_start::Int16
end

struct Pricing
    matrix::Array{Float64, 2}
    feedin::Float32
    grid::Float32
    peer::Float32
    network::Float32
    tax::Float32
    eeg::Float32
    others::Float32
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
    presolve_flag::Int16
end
