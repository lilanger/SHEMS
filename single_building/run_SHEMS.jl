include("main.jl");
include("SHEMS_optimizer.jl");
include("SHEMS_optimizer_seco.jl");
include("SHEMS_optimizer_sesu.jl");

function yearly_SHEMS(h_start=1, h_end=8760, objective=1, case=1, costfactor=1.0, outputflag=true, bc_violations=79)

    # Initialize technical setup according to case______________________
    # set_SHEMS_parameters(h_start, h_end, h_predict, h_control, rolling_flag, costfactor)
    sh, hp, fh, hw, b, m = set_SHEMS_parameters(h_start, h_end, (h_end-h_start)+1, (h_end-h_start)+1, false, case, costfactor, outputflag);

    if objective==1   # minimize costs
        results  = SHEMS_optimizer(sh, hp, fh, hw, b, m);
    elseif objective==2  # maximize self-consumption
        results  = SHEMS_optimizer_seco(sh, hp, fh, hw, b, m, bc_violations);
    elseif objective==3  # maximize self-sufficiency
        results  = SHEMS_optimizer_sesu(sh, hp, fh, hw, b, m, bc_violations);
    end

    # write to results folder___________________________________________________
    write_to_results_file(hcat(results, ones(size(results,1))*m.h_predict), m, objective, case, costfactor)
    return nothing
end

function roll_SHEMS(h_start, h_end, h_predict, h_control, case=1, costfactor=1.0, outputflag=false)

    # Initialize technical setup__________________________________________________
    # set_SHEMS_parameters(h_start, h_end, h_predict, h_control, rolling_flag, costfactor, outputflag)
    sh, hp, fh, hw, b, m = set_SHEMS_parameters(h_start, h_end, h_predict, h_control, true, costfactor, case, outputflag);

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
    write_to_results_file(hcat(results, ones(size(results,1))*m.h_predict), m, 1, case, costfactor)
    return nothing
end

function set_SHEMS_parameters(h_start, h_end, h_predict, h_control, rolling_flag, case=1, costfactor=1.0, outputflag=false)

    # Initialize technical setup________________________________________________
    # Model_SHEMS(h_start, h_end, h_predict, h_control, big, rolling_flag, mip_gap, output_flag, presolve_flag)
    m = Model_SHEMS(h_start, h_end,  h_predict, h_control, 60, rolling_flag, 0.005f0, outputflag, -1);
    hp = HeatPump(1.0f0, 3.0f0);    # HeatPump(eta, rate_max)
    fh = ThermalStorage(1.0f0, 10.0f0, 0.045f0, 30.0f0, 20.0f0, 22.0f0);    # ThermalStorage(eta, volume, loss, t_supply, soc_min, soc_max)
    hw = ThermalStorage(1.0f0, 180.0f0, 0.035f0, 45.0f0, 20.0f0, 180.0f0);  # ThermalStorage(eta, volume, loss, t_supply, soc_min, soc_max)

    if case==1 # base case
        b = Battery(0.95f0, 0.0f0, 13.5f0, 3.3f0, 0.00003f0);  # Battery(eta, soc_min, soc_max, rate_max, loss)
        sh = SHEMS(costfactor, 0.3f0, 0.1f0, 13.5f0, 22.0f0, 180.0f0, h_start); # SHEMS(costfactor, p_buy, p_sell, soc_b, soc_fh, soc_hw, h_start)
    elseif case==2 # no battery
        b = Battery(0.95f0, 0.0f0, 0.0f0, 0.0f0, 0.00003f0);    # set soc_max, rate_max to zero for no battery
        sh = SHEMS(costfactor, 0.3f0, 0.1f0, 0.0f0, 22.0f0, 180.0f0, h_start);  # soc_b zero for no battery
    elseif case==3 # no grid feed-in compensation
        b = Battery(0.95f0, 0.0f0, 13.5f0, 3.3f0, 0.00003f0);   # Battery(eta, soc_min, soc_max, rate_max, loss)
        sh = SHEMS(costfactor, 0.3f0, 0.0f0, 13.5f0, 22.0f0, 180.0f0, h_start); # set p_sell to zero for no feedin tariff
    elseif case==3 # no battery and no grid feed-in compensation
        b = Battery(0.95f0, 0.0f0, 0.0f0, 0.0f0, 0.00003f0);    # Battery(eta, soc_min, soc_max, rate_max, loss)
        sh = SHEMS(costfactor, 0.3f0, 0.0f0, 0.0f0, 22.0f0, 180.0f0, h_start);  # set p_sell to zero for no feedin tariff
    end

    return sh, hp, fh, hw, b, m
end

function write_to_results_file(results, m, objective=1, case=1, costfactor=1.0)
    date=200531;
    CSV.write("results/$(date)_results_$(m.h_predict)_$(m.h_control)_$(m.h_start)-$(m.h_end)_$(objective)_$(case)_$(costfactor).csv", DataFrame(results),
        header=["Temp_FH", "Vol_HW", "Soc_B", "V_HW_plus", "V_HW_minus", "T_FH_plus", "T_FH_minus", "profits", "COP_FH", "COP_HW",
        "PV_DE", "B_DE", "GR_DE", "PV_B", "PV_GR", "PV_HP","GR_HP", "B_HP", "HP_FH", "HP_HW",
        "month", "day", "hour", "horizon"]);

    return nothing
end

function COPcalc(ts, t_outside)
    # Calculate coefficients of performance for every time period (1:h_predict)
    return cop = max.((5.8*ones(size(t_outside,1))) -(1. /14) * abs.((ts.t_supply*ones(size(t_outside,1))) -t_outside), 0);
end
