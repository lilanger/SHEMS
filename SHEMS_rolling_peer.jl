function SHEMS_rolling_peer(sh::SHEMS)
    # initialize technical setup
    hp = HeatPump(1.0f0, 3.0f0);
    fh = ThermalStorage(1.0f0, 10.0f0, 0.045f0, 30.0f0, 20.0f0, 22.0f0);
    hw = ThermalStorage(1.0f0, 180.0f0, 0.035f0, 45.0f0, 20.0f0, 180.0f0);
    b = Battery(0.95f0, 0.0f0, 13.5f0, 3.3f0, 0.0001f0);
    pm = PeerMarket(0.99f0, 0.3f0, 0.1f0, 0.15f0);
    m = Model_SHEMS(0.5f0, 0, 0);

    # Input data__________________________________________________________________________________________________________________________________________________________
    df = CSV.read("data/200124_datafile_all_details_right_timestamp.csv");
    h_last = sh.h_start + sh.h_predict -1;                     # optimization horizon

    # all peers have the same demand
    d_e = df[sh.h_start:h_last,:electkwh];                     # electricity demand 1 year from BeOpt
    d_fh = df[sh.h_start:h_last,:heatingkwh];                  # heating demand 1 year from BeOpt
    d_hw = df[sh.h_start:h_last,:hotwaterkwh];                 # hot water demand 1 year from BeOpt
    g_e = df[sh.h_start:h_last,:PV_generation];                # electricity generation (from Renewable ninjas)
    t_outside = df[sh.h_start:h_last,:Temperature];            # °C (from Renewable ninjas)

    flows = [:PV_DE, :B_DE, :GR_DE, :PV_B, :PV_GR, :PV_HP, :GR_HP, :B_HP, :HP_FH, :HP_HW, :PV_PM, :B_PM, :PM_DE, :PM_B, :PM_HP];
    p_concr = 2400.0;   #kg/m^3
    c_concr = 1.0;      #kJ/(kg*°C)
    p_water = 997.0;    #kg/m^3
    c_water = 4.184;    #kJ/(kg*°C)

    # Calculate coefficients of performance for every time period (1:h_predict)___________________________________________
    cop_fh = COPcalc(fh::ThermalStorage, t_outside);
    cop_hw = COPcalc(hw::ThermalStorage, t_outside);

    # Model start________________________________________________________________________________________________________________________________________________________
    #Define Model und Solver and settings
    model = Model(optimizer_with_attributes(() -> Gurobi.Optimizer(GUROBI_ENV)))
    set_optimizer_attribute(model, "MIPGap", m.mip_gap)
    set_optimizer_attribute(model, "Presolve", m.presolve_flag)
    set_optimizer_attribute(model, "OutputFlag", m.output_flag)

    @variables(model, begin
        X[1:sh.h_predict, 1:length(flows), 1:sh.n_peers] >= 0;    #1:PV_DE, 2:B_DE, 3:GR_DE, 4:PV_B, 5:PV_GR, 6:PV_HP, 7:GR_HP, 8:B_HP, 9:HP_FH, 10:HP_HW, 11:PV_PM, 12:B_PM, 13:PM_DE, 14:PM_B, 15:PM_HP
        SOC_b[1:sh.h_predict, 1:sh.n_peers]  >= 0;
        SOC_fh[1:sh.h_predict, 1:sh.n_peers] >= 0;
        SOC_hw[1:sh.h_predict, 1:sh.n_peers] >= 0;
        Mod_fh[1:sh.h_predict, 1:sh.n_peers] >= 0;
        Mod_hw[1:sh.h_predict, 1:sh.n_peers]   >= 0;
        SOC_fh_plus[1:sh.h_predict, 1:sh.n_peers] >= 0;
        SOC_fh_minus[1:sh.h_predict, 1:sh.n_peers] >= 0;
        SOC_hw_plus[1:sh.h_predict, 1:sh.n_peers] >= 0;
        SOC_hw_minus[1:sh.h_predict, 1:sh.n_peers] >= 0;
        HP_switch[1:sh.h_predict, 1:sh.n_peers], Bin;
        Hot[1:sh.h_predict, 1:sh.n_peers], Bin;
    end)

    # Fix start SoCs
    fix.(SOC_b[1,:], sh.soc_b[:]; force=true);
    fix.(SOC_fh[1,:],sh.soc_fh[:]; force=true);
    fix.(SOC_hw[1,:],sh.soc_hw[:]; force=true);

    # Peer 1 with full functionality
    if sh.n_peers >= 2
        # Peer 2 has no PV and no Battery
        fix.(SOC_b[:, 2], 0; force=true);
        fix.(X[:, [1,2,4,5,6,8,11,12,14], 2], 0; force=true);  # 1:PV_DE, 2:B_DE, 4:PV_B, 5:PV_GR, 6:PV_HP, 8:B_HP, 11:PV_PM, 12:B_PM, 14:PM_B
        if sh.n_peers >= 3
            # Peer 3 is not participating at the peer market
            fix.(X[:, [11,12,13,14,15], 3], 0; force=true);  # 11:PV_PM, 12:B_PM, 13:PM_DE, 14:PM_B, 15:PM_HP
            if sh.n_peers >= 4
                # Peer 4 has no PV and no Battery and is not participating at the peer market
                fix.(SOC_b[:, 4], 0; force=true);
                fix.(X[:, [1,2,4,5,6,8,11,12,13,14,15], 4], 0; force=true);  # 1:PV_DE, 2:B_DE, 4:PV_B, 5:PV_GR, 6:PV_HP, 8:B_HP, 11:PV_PM, 12:B_PM, 13:PM_DE, 14:PM_B, 15:PM_HP
                if sh.n_peers >= 5
                    # Peer 5 has no Battery
                    fix.(SOC_b[:, 5], 0; force=true);
                    fix.(X[:, [2,4,8,12,14], 5], 0; force=true);  # 2:B_DE, 4:PV_B, 8:B_HP, 12:B_PM, 14:PM_B
                end
            end
        end
    end

    #1:PV_DE, 2:B_DE, 3:GR_DE, 4:PV_B, 5:PV_GR, 6:PV_HP, 7:GR_HP, 8:B_HP, 9:HP_FH, 10:HP_HW, 11:PV_PM, 12:B_PM, 13:PM_DE, 14:PM_B, 15:PM_HP
    # Objective function: maximize profit, minimize comfort violations_____________________________________________________________________
    @objective(model, Max, sum( sum( (pm.p_sell *X[h,5,n]) +pm.p_peer *(pm.eta *X[h,11,n] +pm.eta *b.eta *X[h,12,n]) -sum(pm.p_buy *pm.eta *X[h,i,n] for i=[3,7])
        -sum(pm.p_peer *X[h,i,n] for i=[13,14,15]) -(1*(SOC_hw_plus[h,n] +SOC_hw_minus[h,n] +SOC_fh_plus[h,n] +SOC_fh_minus[h,n]))  for h=1:sh.h_predict) for n=1:sh.n_peers));

    # Electricity demand, generation, market clearing___________________________________
    @constraints(model, begin
        [h=1:sh.h_predict, n=1:sh.n_peers],     X[h,1,n] + sum(pm.eta *X[h,i,n] for i=[3,13]) + pm.eta *b.eta *X[h,2,n] >= d_e[h];     # fulfill energy demand (== for max. self-consmption)
        [h=1:sh.h_predict, n=1:sh.n_peers],     sum(X[h,i,n] for i=[1,4,5,6,11]) <= g_e[h];                                            # restricted by PV generation
        [h=1:sh.h_predict],                     sum(pm.eta *X[h,11,n] + pm.eta *b.eta *X[h,12,n] for n=1:sh.n_peers) ==
                                                    sum( sum( X[h,i,n] for n=1:sh.n_peers) for i=13:15);                               # market clearing peer market
    end)
    # Battery__________________________________________________________________________
    @constraints(model, begin
        [h=1:sh.h_predict-1, n=1:sh.n_peers],   SOC_b[h+1,n] == (1 -b.loss) *SOC_b[h,n]+
                                                    pm.eta *X[h,4,n] +pm.eta * b.eta *X[h,14,n]-
                                                    sum(X[h,i,n] for i=[2,8,12]);                    # State of Charge, loss for unique solutions
        [h=1:sh.h_predict, n=1:sh.n_peers],     b.soc_min <= SOC_b[h,n] <= b.soc_max;                # Limits Battery usable capacity
        [h=1:sh.h_predict, n=1:sh.n_peers],     sum(X[h,i,n] for i=[2,4,8,12,14]) <= b.rate_max;     # limit discharging/charging to nominal power (never at same time)
    end)
    # Heat pump_______________________________________________________________________________
    @constraints(model, begin
        [h=1:sh.h_predict, n=1:sh.n_peers],     sum(X[h,i,n] for i=[9,10]) <= X[h,6,n] +
                                                    sum(pm.eta *X[h,i,n] for i=[7,8]) +
                                                    pm.eta * b.eta *X[h,15,n];                          # level power heat pump=and out (== for max. self-consmption)
        [h=1:sh.h_predict, n=1:sh.n_peers],     X[h,9,n] == Mod_fh[h,n] *hp.rate_max;                   # heating energy FH max cap
        [h=1:sh.h_predict, n=1:sh.n_peers],     X[h,10,n] == Mod_hw[h,n] *hp.rate_max;                  # heating energy HW max cap
        #[h=1:sh.h_predict, n=1:sh.n_peers],    Mod_hw[h,n] + Mod_fh[h,n] >= 0.1;                       # minimum level on?
        [h=1:sh.h_predict, n=1:sh.n_peers],     Mod_fh[h,n] <= 1 -HP_switch[h,n];                       # switch FH or HW
        [h=1:sh.h_predict, n=1:sh.n_peers],     Mod_hw[h,n] <= HP_switch[h,n];                          # switch HW or FH
    end)
    # Floor_heating__________________________________________________________________________________________
    @constraints(model, begin
        [h=1:sh.h_predict-1, n=1:sh.n_peers],   SOC_fh[h+1,n] == SOC_fh[h,n]+
                                                    (((X[h,9,n]*cop_fh[h]) -d_fh[h]-
                                                    (fh.loss*(1-Hot[h,n]))+
                                                    (fh.loss*Hot[h,n]))*60*60)/(p_concr*fh.vol*c_concr);    # SoC floor heating (temperature)
        [h=1:sh.h_predict, n=1:sh.n_peers],     fh.soc_min -SOC_fh_minus[h,n] <= SOC_fh[h,n];               # Limits temperature FH min
        [h=1:sh.h_predict, n=1:sh.n_peers],     SOC_fh[h,n] <= fh.soc_max +SOC_fh_plus[h,n];                # Limits temperature FH max
        [h=1:sh.h_predict, n=1:sh.n_peers],     SOC_fh[h,n] - (1 -Hot[h,n])*60 <= t_outside[h];             # force hot binary on if hotter outside than inside
        [h=1:sh.h_predict, n=1:sh.n_peers],     t_outside[h] -Hot[h,n]*60 <= SOC_fh[h,n];
    end)
    #Hot water_____________________________________________________________________________________________
    @constraints(model, begin
        [h=1:sh.h_predict-1, n=1:sh.n_peers],   SOC_hw[h+1,n] == SOC_hw[h,n]+
                                                    (((X[h,10,n]*cop_hw[h]) -d_hw[h]-
                                                    hw.loss)*60*60)/((p_water*hw.t_supply*c_water)/1000);   # SoC hot water (volume)
        [h=1:sh.h_predict, n=1:sh.n_peers],     hw.soc_min - SOC_hw_minus[h,n] <= SOC_hw[h,n];              # Limits volume HW min
        [h=1:sh.h_predict, n=1:sh.n_peers],     SOC_hw[h,n] <= hw.soc_max +SOC_hw_plus[h,n];                # Limits volume HW max
    end)

    JuMP.optimize!(model);

    # collect returns
    profits = zeros(sh.h_control, sh.n_peers);
    results = Array{Any}(undef, (sh.h_control*sh.n_peers, 11+15+3));    # optimization variables + flows + month + day + hour
    for n=1:sh.n_peers
        for k=1:sh.h_control
            profits[k,n] = (pm.p_buy *JuMP.value.(X[k,5,n])) - (pm.p_sell *(JuMP.value.(X[k,3,n]) +JuMP.value.(X[k,7,n])));
        end

        results[((n-1)*sh.h_control)+1:(n*sh.h_control),1:11] =
            hcat(JuMP.value.(SOC_fh[1:sh.h_control,n]), JuMP.value.(SOC_hw[1:sh.h_control,n]), JuMP.value.(SOC_b[1:sh.h_control,n]),
            JuMP.value.(SOC_hw_plus[1:sh.h_control,n]), JuMP.value.(SOC_hw_minus[1:sh.h_control,n]),
            JuMP.value.(SOC_fh_plus[1:sh.h_control,n]), JuMP.value.(SOC_fh_minus[1:sh.h_control,n]),
            profits[:,n], cop_fh[1:sh.h_control], cop_hw[1:sh.h_control], (ones(sh.h_control)*n));
        results[((n-1)*sh.h_control)+1:(n*sh.h_control),12:26] = JuMP.value.(X[1:sh.h_control,:,n]);                       # flow variables
        results[((n-1)*sh.h_control)+1:(n*sh.h_control),27:end] .= df[sh.h_start:(sh.h_start + sh.h_control -1), 13:15];   # month + day + hour
    end

    return JuMP.value.(SOC_b[sh.h_control+1,:]), JuMP.value.(SOC_fh[sh.h_control+1,:]), JuMP.value.(SOC_hw[sh.h_control+1,:]), results
end
