include("main.jl");
include("SHEMS_optimizer_peer.jl");

function roll_SHEMS(market_flag, n_peers, n_market, h_start, h_end, h_predict, h_control, case)
    # Initialize technical setup__________________________________________________
    sh, pv, hp, fh, hw, b, m, p = set_SHEMS_parameters(market_flag, n_peers, n_market,
                                                h_start, h_end, h_predict, h_control, case);
    # intitial run_______________________________________________________________
    sh.soc_b, sh.soc_fh, sh.soc_hw, results_new  = SHEMS_optimizer_peer(sh, pv, hp, fh, hw, b, m, p);
    results = results_new;
    sh.h_start = m.h_start + m.h_control;

    # loop runs for rest of horizon______________________________________________
    for h = sh.h_start:m.h_control:(m.h_end-m.h_predict)
        sh.h_start = h;
        sh.soc_b, sh.soc_fh, sh.soc_hw, results_new  = SHEMS_optimizer_peer(sh, pv, hp, fh, hw, b, m, p);
        results = vcat(results, results_new);
    end

    # write to results folder____________________________________________________
    write_to_results_file(results, m, market_flag, n_peers, n_market, case)
    return nothing
end

function set_SHEMS_parameters(market_flag, n_peers, n_market, h_start, h_end, h_predict, h_control, case)
    # Initialize technical setup________________________________________________
    # Model_SHEMS(h_start, h_end, h_predict, h_control, big, rolling_flag, solver, mip_gap, output_flag, presolve_flag)
    m = Model_SHEMS(h_start, h_end,  h_predict, h_control, 60, "Gurobi", 0.005f0, 0, -1);
    # PV(eta_i)
    pv = PV(0.95f0);
    # HeatPump(rate_max)
    hp = HeatPump(3.0f0);
    # ThermalStorage(volume, loss, t_supply, soc_min, soc_max)
    fh = ThermalStorage(10.0f0, 0.045f0, 30.0f0, 20.0f0, 22.0f0);
    hw = ThermalStorage(180.0f0, 0.035f0, 45.0f0, 20.0f0, 180.0f0);
    # Battery(eta_i, eta_b, soc_min, soc_max, rate_max, loss)
    b = Battery(0.98f0, 0.0f0, 10.0f0, 4.6f0, 0.00003f0);
    # SHEMS(market_flag, n_peers, n_market, soc_b, soc_fh, soc_hw, h_start)
    sh = SHEMS(market_flag, n_peers, n_market, ones(n_peers*n_market).*0.0f0,
                ones(n_peers*n_market).*22.0f0, ones(n_peers*n_market).*180.0f0, h_start);

    if case==1 # feed-in tariff, full charge
        # Pricing(feedin, grid, peer, network, tax, eeg, others)
        p = Pricing(Matrix(CSV.read("data/tariff_matrix_case_1.csv")), 9.87, 12.19, 24.39, 7.71, 2.05, 6.756, 2.667)
    elseif case==2 # no feed-in tariff, full charge
        p = Pricing(Matrix(CSV.read("data/tariff_matrix_case_2.csv")), 9.87, 12.19, 24.39, 7.71, 2.05, 6.756, 2.667)
    elseif case==3 # feed-in tariff, support charge
        p = Pricing(Matrix(CSV.read("data/tariff_matrix_case_3.csv")), 9.87, 12.19, 24.39, 7.71, 2.05, 6.756, 2.667)
    elseif case==4 # no feed-in tariff, support charge
        p = Pricing(Matrix(CSV.read("data/tariff_matrix_case_4.csv")), 9.87, 12.19, 24.39, 7.71, 2.05, 6.756, 2.667)
    elseif case==5 # no feed-in tariff, area network
        p = Pricing(Matrix(CSV.read("data/tariff_matrix_case_5.csv")), 9.87, 12.19, 24.39, 7.71, 2.05, 6.756, 2.667)
    elseif case==6 # no feed-in tariff, area network
        p = Pricing(Matrix(CSV.read("data/tariff_matrix_case_6.csv")), 9.87, 12.19, 24.39, 7.71, 2.05, 6.756, 2.667)
    end

    return sh, pv, hp, fh, hw, b, m, p
end

function write_to_results_file(results, m, market_flag=1, n_peers=3, n_market=1, case=1)
    date=200829;
    CSV.write("results/$(date)_results_$(m.h_predict)_$(m.h_control)_$(m.h_start)-$(m.h_end)"*
                "_$(market_flag)_$(n_peers)_$(n_market)_$(case).csv",
            DataFrame(results), header=["Temp_FH", "Vol_HW",
            "SOC_B", "T_FH_plus", "T_FH_minus", "V_HW_plus", "V_HW_minus",  "profits", "sell",
            "COP_FH", "COP_HW", "Peer",
            "PV_DE", "B_DE", "GR_DE", "PV_B", "PV_GR", "PV_HP","GR_HP", "B_HP", "HP_FH", "HP_HW",
            "PV_PM", "B_PM", "PM_DE", "PM_HP",
            "month", "day", "hour"]);
    return nothing
end

function COPcalc(ts, t_outside)
    # Calculate coefficients of performance for every time period (1:h_predict)
    return cop = max.((5.8*ones(size(t_outside,1))) -(1. /14) * abs.((ts.t_supply*ones(size(t_outside,1)))-
                        t_outside), 0);
end

function run_cases(start_n, stop_n, start_c, stop_c)
    for n in start_n:stop_n
        print("$n  ");
        for c in start_c:stop_c
            print("$c  ")
            println(@elapsed roll_SHEMS(1, n, 1, 1, 8760, 36, 12, c))
        end
    end
    return nothing
end



#=
function touPrices(h_predict, h_control, p_buy)
    # Calculate the purchase market price TOU: off-peak=p_buy, other= p_buy*2
    TOU = ((mod.(1:(h_predict +h_control+1).-1,24).> 6).+1) *p_buy
    return TOU;
end

function peerPrices(proBuy, p_buy, p_sell)
    # Calculate reservation purchase price and reservation sales price
    p_peer= (1-proBuy)*((1 - 0.1)/(1 + 0.05)) .* p_buy .+
            proBuy*(((1 + 0.1)/(1 - 0.05)) * p_sell);
    return p_peer
end
=#
