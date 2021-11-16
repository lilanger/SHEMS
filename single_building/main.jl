using JuMP, Cbc, CSV, DataFrames;
# for using the Gurobi solver (license needed)
using Gurobi
GUROBI_ENV = Gurobi.Env() # Gurobi academic license message only once

struct PV
    eta::Float32
end

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
    SOC_b::Float32
    T_fh::Float32
    V_hw::Float32
    h_start::Int16
end

struct Model_SHEMS
    h_start::Int16
    h_end::Int16
    h_predict::Int16
    h_control::Int16
    big::Int16
    rolling_flag::Bool
    solver::String
    mip_gap::Float32
    output_flag::Bool
    presolve_flag::Int
    season::String
    run::String
    price::String
end

# Horizon lengths
H_LENGTH = Dict(("all", "all") => 8760,
                    ("summer", "eval") => 360, ("summer", "test") => 768,
                    ("winter", "eval") => 360, ("winter", "test") => 720,
                    ("both", "eval") => 720,   ("both", "test") => 1488,
                    ("all", "eval") => 1440,   ("all", "test") => 3000);
