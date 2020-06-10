include("main.jl");
include("SHEMS_optimizer_peer.jl");

function roll_SHEMS(n_peers, h_start, h_end, h_predict, h_control, costfactor=1.0, outputflag=0)
    # Initialize technical setup__________________________________________________
    # set_SHEMS_parameters(h_start, h_end, h_predict, h_control, rolling_flag, costfactor, outputflag)
    sh, hp, fh, hw, b, m = set_SHEMS_parameters(n_peers, h_start, h_end, h_predict, h_control,
                                                    costfactor, outputflag);
    # intitial run_______________________________________________________________
    sh.soc_b, sh.soc_fh, sh.soc_hw, results_new  = SHEMS_optimizer_peer(sh, hp, fh, hw, b, m);
    results = results_new;
    sh.h_start = m.h_start + m.h_control;

    # loop runs for rest of horizon______________________________________________
    for h = sh.h_start:m.h_control:(m.h_end-m.h_predict)
        sh.h_start = h;
        sh.soc_b, sh.soc_fh, sh.soc_hw, results_new  = SHEMS_optimizer_peer(sh, hp, fh, hw, b, m);
        results = vcat(results, results_new);
    end

    # write to results folder____________________________________________________
    write_to_results_file(results, m, n_peers, costfactor)
    return nothing
end

function set_SHEMS_parameters(n_peers, h_start, h_end, h_predict, h_control, costfactor=1.0, outputflag=0)
    # Initialize technical setup________________________________________________
    # Model_SHEMS(h_start, h_end, h_predict, h_control, big, rolling_flag, solver, mip_gap, output_flag, presolve_flag)
    m = Model_SHEMS(h_start, h_end,  h_predict, h_control, 60, "Gurobi", 0.005f0, outputflag, -1);
    # HeatPump(rate_max)
    hp = HeatPump(3.0f0);
    # ThermalStorage(volume, loss, t_supply, soc_min, soc_max)
    fh = ThermalStorage(10.0f0, 0.045f0, 30.0f0, 20.0f0, 22.0f0);
    hw = ThermalStorage(180.0f0, 0.035f0, 45.0f0, 20.0f0, 180.0f0);
    # Battery(eta, soc_min, soc_max, rate_max, loss)
    b = Battery(0.95f0, 0.0f0, 13.5f0, 3.3f0, 0.00003f0);
    # SHEMS(n_peers, costfactor, p_buy, p_sell, soc_b, soc_fh, soc_hw, h_start)
    sh = SHEMS(n_peers, costfactor, 0.3f0, 0.1f0, 0.15f0, ones(n_peers).*13.5f0, ones(n_peers).*22.0f0, ones(n_peers).*180.0f0, h_start);

    return sh, hp, fh, hw, b, m
end

function write_to_results_file(results, m, n_peers=5, costfactor=1.0)
    date=200609;
    CSV.write("results/$(date)_results_$(m.h_predict)_$(m.h_control)_$(m.h_start)-$(m.h_end)_$(n_peers)_$(costfactor).csv", 
            DataFrame(results), header=["Temp_FH", "Vol_HW",
            "SOC_B", "T_FH_plus", "T_FH_minus", "V_HW_plus", "V_HW_minus",  "profits",
            "COP_FH", "COP_HW", "Peer",
            "PV_DE", "B_DE", "GR_DE", "PV_B", "PV_GR", "PV_HP","GR_HP", "B_HP", "HP_FH", "HP_HW",
            "PV_PM", "B_PM", "PM_DE", "PM_B", "PM_HP",
            "month", "day", "hour"]);
    return nothing
end

function COPcalc(ts, t_outside)
    # Calculate coefficients of performance for every time period (1:h_predict)
    return cop = max.((5.8*ones(size(t_outside,1))) -(1. /14) * abs.((ts.t_supply*ones(size(t_outside,1)))-
                        t_outside), 0);
end
