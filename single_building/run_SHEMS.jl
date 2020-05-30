include("main.jl")

function yearly_SHEMS(h_start=1, h_end=8760, costfactor=1, objective=1, bc_violations=79, outputflag=true)
    # Initialize technical setup________________________________________________
    # set_SHEMS_parameters(h_start, h_end, h_predict, h_control, rolling_flag, costfactor)
    sh, hp, fh, hw, b, m = set_SHEMS_parameters(h_start, h_end, (h_end-h_start)+1, (h_end-h_start)+1, false, costfactor, outputflag);
    if objective==1
        include("single_building/SHEMS_optimizer.jl")
        # minimize costs
        run= "Feedin+_battery+_mc";
        results  = SHEMS_optimizer(sh, hp, fh, hw, b, m);
    elseif objective==2
        include("single_building/SHEMS_optimizer_seco.jl")
        # maximize self-consumption
        run= "Feedin+_battery+_seco";
        results  = SHEMS_optimizer_seco(sh, hp, fh, hw, b, m, bc_violations);
    elseif objective==3
        include("single_building/SHEMS_optimizer_sesu.jl")
        # maximize self-sufficiency
        run= "Feedin+_battery+_sesu";
        results  = SHEMS_optimizer_sesu(sh, hp, fh, hw, b, m, bc_violations);
    end
    # write to results folder___________________________________________________
    date=200530;
    write_to_results_file(hcat(results, ones(size(results,1))*m.h_predict), m, date, run, costfactor)
    return nothing
end

function roll_SHEMS(h_start, h_end, h_predict, h_control, costfactor, outputflag=false)
    include("SHEMS_optimizer.jl")
    # Initialize technical setup__________________________________________________
    # set_SHEMS_parameters(h_start, h_end, h_predict, h_control, rolling_flag, costfactor, outputflag)
    sh, hp, fh, hw, b, m = set_SHEMS_parameters(h_start, h_end, h_predict, h_control, true, costfactor, outputflag);
    # intitial run_______________________________________________________________
    sh.soc_b, sh.soc_fh, sh.soc_hw, results_new  = SHEMS_optimizer(sh, hp, fh, hw, b, m);
    results = results_new;
    sh.h_start = m.h_start + m.h_control;
    # loop runs for rest of horizon______________________________________________
    for h = sh.h_start:m.h_control:(m.h_end-m.h_predict)
        sh.h_start = h;
        sh.soc_b, sh.soc_fh, sh.soc_hw, results_new  = SHEMS_optimizer(sh, hp, fh, hw, b, m);
        results = vcat(results, results_new);
    end
    # write to results folder____________________________________________________
    date=200530;
    run= "Feedin+_battery+_mc";
    write_to_results_file(hcat(results, ones(size(results,1))*m.h_predict), m, date, run, costfactor)
    return nothing
end

function set_SHEMS_parameters(h_start, h_end, h_predict, h_control, rolling_flag, costfactor, outputflag)
    # Initialize technical setup________________________________________________
    # SHEMS(costfactor, p_buy, p_sell, soc_b, soc_fh, soc_hw, h_start)
    # set p_sell to zero for no feedin tariff, soc_b zero for no battery
    sh = SHEMS(costfactor, 0.3f0, 0.1f0, 13.5f0, 22.0f0, 180.0f0, h_start);
    # HeatPump(eta, rate_max)
    hp = HeatPump(1.0f0, 3.0f0);
    # ThermalStorage(eta, volume, loss, t_supply, soc_min, soc_max)
    fh = ThermalStorage(1.0f0, 10.0f0, 0.045f0, 30.0f0, 20.0f0, 22.0f0);
    # ThermalStorage(eta, volume, loss, t_supply, soc_min, soc_max)
    hw = ThermalStorage(1.0f0, 180.0f0, 0.035f0, 45.0f0, 20.0f0, 180.0f0);
    # Battery(eta, soc_min, soc_max, rate_max, loss)
    # set soc_max, rate_max to zero for no battery
    b = Battery(0.95f0, 0.0f0, 13.5f0, 3.3f0, 0.00003f0);
    # Model_SHEMS(h_start, h_end, h_predict, h_control, big, rolling_flag, mip_gap, output_flag, presolve_flag)
    m = Model_SHEMS(h_start, h_end,  h_predict, h_control, 60, rolling_flag, 0.005f0, outputflag, -1);
    return sh, hp, fh, hw, b, m
end

function write_to_results_file(all, m, date, run, costfactor=1)
    CSV.write("single_building/results/$(date)_results_$(m.h_predict)_$(m.h_control)_$(m.h_start)-$(m.h_end)_$(run)_$(costfactor).csv", DataFrame(all),
        header=["Temp_FH", "Vol_HW", "Soc_B", "V_HW_plus", "V_HW_minus", "T_FH_plus", "T_FH_minus", "profits", "COP_FH", "COP_HW",
        "PV_DE", "B_DE", "GR_DE", "PV_B", "PV_GR", "PV_HP","GR_HP", "B_HP", "HP_FH", "HP_HW",
        "month", "day", "hour", "horizon"]);
    return nothing
end

function COPcalc(ts, t_outside)
    # Calculate coefficients of performance for every time period (1:h_predict)
    return cop = max.((5.8*ones(size(t_outside,1))) -(1. /14) * abs.((ts.t_supply*ones(size(t_outside,1))) -t_outside), 0);
end
