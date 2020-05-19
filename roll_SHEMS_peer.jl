function roll_SHEMS_peer(n_peers=5)
    sh = SHEMS(n_peers, 1, 8760,  24, 6, ones(n_peers).*13.5f0, ones(n_peers).*22.0f0, ones(n_peers).*180.0f0);  #360
    h_start = sh.h_start;
    # loop runs for first
    results = Array{Any}(undef, (sh.h_control*sh.n_peers, 11+15+1));
    sh.soc_b, sh.soc_fh, sh.soc_hw, results_new  = SHEMS_rolling_peer(sh::SHEMS);
    results[1:(sh.n_peers*sh.h_control), :] = results_new;
    sh.h_start += sh.h_control;

    for h = sh.h_start:sh.h_control:(sh.h_end-sh.h_predict)
        sh.h_start = h;
        sh.soc_b, sh.soc_fh, sh.soc_hw, results_new  = SHEMS_rolling_peer(sh::SHEMS);          # loop runs for rest of horizon
        results = vcat(results, results_new);
    end

    all = hcat(results, ones(size(results,1))*sh.h_predict);
    date=200421;
    CSV.write("results/$(date)_results_$(sh.h_predict)_$(sh.h_control)_$(sh.n_peers)_$(h_start)-$(sh.h_end).csv", DataFrame(all),
        header=["Temp_FH", "Vol_HW", "Soc_B", "SoC_HW_plus", "SoC_HW_minus", "SoC_FH_plus", "SoC_FH_minus", "profits", "COP_FH", "COP_HW", "Peer",
        "PV_DE", "B_DE", "GR_DE", "PV_B", "PV_GR", "PV_HP","GR_HP", "B_HP", "HP_FH", "HP_HW", "PV_PM", "B_PM", "PM_DE", "PM_B", "PM_HP",
        "Date/Time", "horizon"]);
        #"heating", "heating_fan", "hotwater", "lights", "lgappl", "vent_fan", "misc", "D_elect",
        #"D_heating", "D_hotwater", "Date/Time", "PV_generation", "Temperature", "horizon"]);
end
