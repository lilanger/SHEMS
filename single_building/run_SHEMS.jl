include("main.jl");
include("SHEMS_optimizer.jl");
include("SHEMS_optimizer_seco.jl");
include("SHEMS_optimizer_sesu.jl");

function yearly_SHEMS(h_start=1, objective=1, case=1, costfactor=1.0, outputflag=1;
                        bc_violations=79, season="all", run="all", price="fix")

    # Initialize technical setup according to case______________________
    # set_SHEMS_parameters(h_start, h_end, h_predict, h_control, rolling_flag, costfactor)
    sh, hp, fh, hw, b, m, pv = set_SHEMS_parameters(h_start, H_LENGTH[season, run], (H_LENGTH[season, run]-h_start)+1,
                                                    (H_LENGTH[season, run]-h_start)+1,
                                                    false, case, costfactor, outputflag,
                                                    season=season, run=run, price=price);

    if objective==1   # minimize costs (default)
        results  = SHEMS_optimizer(sh, hp, fh, hw, b, m, pv);
    elseif objective==2  # maximize self-consumption
        results  = SHEMS_optimizer_seco(sh, hp, fh, hw, b, m, bc_violations); # pv missing (eta)
    elseif objective==3  # maximize self-sufficiency
        results  = SHEMS_optimizer_sesu(sh, hp, fh, hw, b, m, bc_violations); # pv missing (eta)
    end

    # write to results folder___________________________________________________
    write_to_results_file(hcat(results, ones(size(results,1))*m.h_predict), m, objective, case, costfactor)
    return nothing
end

# Rolling horizon implementation
function roll_SHEMS(h_start, h_end, h_predict, h_control, case=1, costfactor=1.0, outputflag=0)
    # Initialize technical setup__________________________________________________
    # set_SHEMS_parameters(h_start, h_end, h_predict, h_control, rolling_flag, costfactor, outputflag)
    sh, hp, fh, hw, b, m, pv = set_SHEMS_parameters(h_start, h_end, h_predict, h_control, true, costfactor,
        case, outputflag);

    # intitial run_______________________________________________________________
    sh.soc_b, sh.soc_fh, sh.soc_hw, results_new  = SHEMS_optimizer(sh, hp, fh, hw, b, m);
    results = results_new;
    sh.h_start = m.h_start + m.h_control;

    # loop runs for rest of horizon______________________________________________
    for h = sh.h_start:m.h_control:(m.h_end-m.h_predict)
        sh.h_start = h;
        sh.soc_b, sh.soc_fh, sh.soc_hw, results_new  = SHEMS_optimizer(sh, hp, fh, hw, b, m, pv);
        results = vcat(results, results_new);
    end

    # write to results folder____________________________________________________
    write_to_results_file(hcat(results, ones(size(results,1))*m.h_predict), m, 1, case, costfactor)
    return nothing
end

function set_SHEMS_parameters(h_start, h_end, h_predict, h_control, rolling_flag, case=1, costfactor=1.0, outputflag=0;
                                season="all", run="all", price="fix")
    # Initialize technical setup________________________________________________
    # Model_SHEMS(h_start, h_end, h_predict, h_control, big, rolling_flag, solver, mip_gap, output_flag, presolve_flag)
    m = Model_SHEMS(h_start, h_end, h_predict, h_control, 60, rolling_flag, "Cbc", 0.05f0, outputflag, -1,
                        season, run, price);
    # PV(eta)
    pv = PV(0.95f0);
    # HeatPump(eta, rate_max)
    hp = HeatPump(1f0, 3f0);

    if case==1 # base case
        # Battery(eta, soc_min, soc_max, rate_max, loss)
        b = Battery(0.95f0, 0.0f0, 13.5f0, 3.3f0, 0.00003f0);
        # SHEMS(costfactor, p_buy, p_sell, soc_b, soc_fh, soc_hw, h_start)
        sh = SHEMS(costfactor, 0.3f0, 0.1f0, 13.5f0, 22.0f0, 180.0f0, h_start);
        # ThermalStorage(eta, volume, loss, t_supply, soc_min, soc_max)
        fh = ThermalStorage(1.0f0, 10.0f0, 0.045f0, 30.0f0, 20.0f0, 22.0f0);
        hw = ThermalStorage(1.0f0, 180.0f0, 0.035f0, 45.0f0, 20.0f0, 180.0f0);
    elseif case==2 # no battery
        # set soc_max, rate_max to zero for no battery
        b = Battery(0.95f0, 0.0f0, 0.0f0, 0.0f0, 0.00003f0);
        # soc_b zero for no battery
        sh = SHEMS(costfactor, 0.3f0, 0.1f0, 0.0f0, 22.0f0, 180.0f0, h_start);
        # ThermalStorage(eta, volume, loss, t_supply, soc_min, soc_max)
        fh = ThermalStorage(1.0f0, 10.0f0, 0.045f0, 30.0f0, 20.0f0, 22.0f0);
        hw = ThermalStorage(1.0f0, 180.0f0, 0.035f0, 45.0f0, 20.0f0, 180.0f0);
    elseif case==3 # no grid feed-in compensation
        # Battery(eta, soc_min, soc_max, rate_max, loss)
        b = Battery(0.95f0, 0.0f0, 13.5f0, 3.3f0, 0.00003f0);
        # set p_sell to zero for no feedin tariff
        sh = SHEMS(costfactor, 0.3f0, 0.0f0, 13.5f0, 22.0f0, 180.0f0, h_start);
        # ThermalStorage(eta, volume, loss, t_supply, soc_min, soc_max)
        fh = ThermalStorage(1.0f0, 10.0f0, 0.045f0, 30.0f0, 20.0f0, 22.0f0);
        hw = ThermalStorage(1.0f0, 180.0f0, 0.035f0, 45.0f0, 20.0f0, 180.0f0);
    elseif case==4 # no battery and no grid feed-in compensation
        # Battery(eta, soc_min, soc_max, rate_max, loss)
        b = Battery(0.95f0, 0.0f0, 0.0f0, 0.0f0, 0.00003f0);
        # set p_sell to zero for no feedin tariff
        sh = SHEMS(costfactor, 0.3f0, 0.0f0, 0.0f0, 22.0f0, 180.0f0, h_start);
        # ThermalStorage(eta, volume, loss, t_supply, soc_min, soc_max)
        fh = ThermalStorage(1.0f0, 10.0f0, 0.045f0, 30.0f0, 20.0f0, 22.0f0);
        hw = ThermalStorage(1.0f0, 180.0f0, 0.035f0, 45.0f0, 20.0f0, 180.0f0);
    elseif case==5 # RL case study
        # Battery(eta, soc_min, soc_max, rate_max, loss)
        b = Battery(0.98f0, 0.0f0, 10f0, 4.6f0, 0.00003f0);
        # ThermalStorage(eta, volume, loss, t_supply, soc_min, soc_max)
        fh = ThermalStorage(1f0, 10f0, 0.045f0, 30f0, 19f0, 24f0);
        hw = ThermalStorage(1f0, 200f0, 0.035f0, 45f0, 20f0, 180f0);
        # SHEMS(costfactor, p_buy, p_sell, soc_b, soc_fh, soc_hw, h_start)
        sh = SHEMS(costfactor, 0.3f0, 0.1f0, 0.5 * (b.soc_min + b.soc_max), 0.5 * (fh.soc_min + fh.soc_max),
                    0.5 * (hw.soc_min + hw.soc_max), h_start);
    end

    return sh, hp, fh, hw, b, m, pv
end

function write_to_results_file(results, m, objective=1, case=1, costfactor=1.0)
    date=211116;
    CSV.write("single_building/results/$(date)_results_$(m.h_predict)_$(m.h_control)_$(m.h_start)-$(m.h_end)"*
                "_$(objective)_$(case)_$(costfactor)_$(m.season)_$(m.run)_$(m.price).csv",
                DataFrame(results), header=["Temp_FH", "Vol_HW",
                "Soc_B", "V_HW_plus", "V_HW_minus", "T_FH_plus", "T_FH_minus", "profits", "COP_FH",
                "COP_HW","PV_DE", "B_DE", "GR_DE", "PV_B", "PV_GR", "PV_HP","GR_HP", "B_HP", "HP_FH", "HP_HW",
                "month", "day", "hour", "horizon"]);
    return nothing
end

function COPcalc(ts, t_outside)
    # Calculate coefficients of performance for every time period (1:h_predict)
    return cop = max.((5.8*ones(size(t_outside,1))) -(1. /14) * abs.((ts.t_supply*ones(size(t_outside,1)))
            -t_outside), 0);
end


#=
# Calling model runs:
yearly_SHEMS(1, 1, 5, 1.0, 1, season="all", run="eval", price="fix")
yearly_SHEMS(1, 1, 5, 1.0, 1, run="test")
yearly_SHEMS(1, 1, 5, 1.0, 1, season="summer", run="eval", price="fix")
yearly_SHEMS(1, 1, 5, 1.0, 1, season="winter", run="eval", price="fix")
=#