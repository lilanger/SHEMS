function SHEMS_optimizer_peer(sh, pv, hp, fh, hw, b, m, p)
    flows = [:PV_DE, :B_DE, :GR_DE, :PV_B, :PV_GR, :PV_HP, :GR_HP, :B_HP, :HP_FH, :HP_HW, :PV_PM, :B_PM, :PM_DE, :PM_HP];
    p_concr = 2400.0;   # kg/m^3
    c_concr = 1.0;      # kJ/(kg*°C)
    p_water = 997.0;    # kg/m^3
    c_water = 4.184;    # kJ/(kg*°C)
    M=1000;

    # Input data__________________________________________________________________________________________________________________________________________________________
    df = CSV.read("data/200124_datafile_all_details_right_timestamp.csv");
    h_last = sh.h_start + m.h_predict -1;                     # optimization horizon

    # all peers have the same demand
    d_e = df[sh.h_start:h_last,:electkwh];                      # electricity demand 1 year from BeOpt
    d_fh = df[sh.h_start:h_last,:heatingkwh];                   # heating demand 1 year from BeOpt
    d_hw = df[sh.h_start:h_last,:hotwaterkwh];                  # hot water demand 1 year from BeOpt
    g_e = repeat([1 1 0 0 0] .*df[sh.h_start:h_last,:PV_generation], inner=(1, sh.n_market));       # electricity generation (from Renewable ninjas), consumer has no generation
    t_outside = df[sh.h_start:h_last,:Temperature];             # °C (from Renewable ninjas)

    # Calculate coefficients of performance for every time period (1:h_predict)___________________________________________
    cop_fh = COPcalc(fh, t_outside);
    cop_hw = COPcalc(hw, t_outside);

    # Model start________________________________________________________________________________________________________________________________________________________
    #Define Model und Solver and settings
    if m.solver == "Cbc"
        model = Model(optimizer_with_attributes(() -> Cbc.Optimizer()));
        set_optimizer_attribute(model, "ratioGap", m.mip_gap);
        set_optimizer_attribute(model, "logLevel", m.output_flag);
    elseif m.solver == "Gurobi"
        model = Model(optimizer_with_attributes(() -> Gurobi.Optimizer(GUROBI_ENV)));
        set_optimizer_attribute(model, "MIPGap", m.mip_gap);
        set_optimizer_attribute(model, "Presolve", m.presolve_flag);
        set_optimizer_attribute(model, "OutputFlag", m.output_flag);
    end

    @variables(model, begin
        X[1:m.h_predict, 1:length(flows), 1:sh.n_peers*sh.n_market] >= 0;    #1:PV_DE, 2:B_DE, 3:GR_DE, 4:PV_B, 5:PV_GR, 6:PV_HP, 7:GR_HP, 8:B_HP, 9:HP_FH, 10:HP_HW, 11:PV_PM, 12:B_PM, 13:PM_DE, 14:PM_HP
        SOC_b[1:m.h_predict+1, 1:sh.n_peers*sh.n_market]  >= 0;
        B_switch[1:m.h_predict, 1:sh.n_peers*sh.n_market], Bin;
        T_fh[1:m.h_predict+1, 1:sh.n_peers*sh.n_market] >= 0; V_hw[1:m.h_predict+1, 1:sh.n_peers*sh.n_market] >= 0;
        Mod_fh[1:m.h_predict, 1:sh.n_peers*sh.n_market] >= 0; Mod_hw[1:m.h_predict, 1:sh.n_peers*sh.n_market]   >= 0;
        T_fh_plus[1:m.h_predict, 1:sh.n_peers*sh.n_market] >= 0; T_fh_minus[1:m.h_predict, 1:sh.n_peers*sh.n_market] >= 0;
        V_hw_plus[1:m.h_predict, 1:sh.n_peers*sh.n_market] >= 0; V_hw_minus[1:m.h_predict, 1:sh.n_peers*sh.n_market] >= 0;
        HP_switch[1:m.h_predict, 1:sh.n_peers*sh.n_market], Bin;
        Hot[1:m.h_predict], Bin;
        Peer_switch[1:m.h_predict, 1:sh.n_peers*sh.n_market], Bin;
    end)

    # Fix start SoCs
    fix.(SOC_b[1,:],  sh.soc_b[:];  force=true);
    fix.(T_fh[1,:], sh.soc_fh[:]; force=true);
    fix.(V_hw[1,:], sh.soc_hw[:]; force=true);

    # Peer 1 with full functionality PV and battery (Prosumager)
    if sh.n_peers >= 2
        # Peer 2 has no Battery (Prosumer)
        fix.(SOC_b[:, (1*sh.n_market)+1:(2*sh.n_market)], 0; force=true);
        fix.(X[:, [2,4,8,12], (1*sh.n_market)+1:(2*sh.n_market)], 0; force=true);  # 2:B_DE, 4:PV_B, 8:B_HP, 12:B_PM

        if sh.n_peers >= 3
            # Peer 3 has no PV and no Battery (Consumer)
            fix.(SOC_b[:, (2*sh.n_market)+1:(3*sh.n_market)], 0; force=true);
            fix.(X[:, [1,2,4,5,6,8,11,12], (2*sh.n_market)+1:(3*sh.n_market)], 0; force=true);  # 1:PV_DE, 2:B_DE, 4:PV_B, 5:PV_GR, 6:PV_HP, 8:B_HP, 11:PV_PM, 12:B_PM

            if sh.n_peers >= 4
                # Peer 4 has no PV but a Battery (Consumer + B)
                fix.(SOC_b[:, (3*sh.n_market)+1:(4*sh.n_market)], 0; force=true);
                fix.(X[:, [1,2,4,5,6,8,11,12], (3*sh.n_market)+1:(4*sh.n_market)], 0; force=true);  # 1:PV_DE, 2:B_DE, 4:PV_B, 5:PV_GR, 6:PV_HP, 8:B_HP, 11:PV_PM, 12:B_PM

                if sh.n_peers >= 5
                    # Peer 5 has no PV and no Battery (Consumer)
                    fix.(SOC_b[:, (4*sh.n_market)+1:(5*sh.n_market)], 0; force=true);
                    fix.(X[:, [1,2,4,5,6,8,11,12], (4*sh.n_market)+1:(5*sh.n_market)], 0; force=true);  # 1:PV_DE, 2:B_DE, 4:PV_B, 5:PV_GR, 6:PV_HP, 8:B_HP, 11:PV_PM, 12:B_PM
                end
                
            end
        end
    end

    if sh.market_flag < 1 # market is switched off
            fix.(X[:, [11,12,13,14], :], 0; force=true);
    end

    #1:PV_DE, 2:B_DE, 3:GR_DE, 4:PV_B, 5:PV_GR, 6:PV_HP, 7:GR_HP, 8:B_HP, 9:HP_FH, 10:HP_HW, 11:PV_PM, 12:B_PM, 13:PM_DE, 14:PM_HP
    # Objective function: maximize profit, minimize comfort violations_____________________________________________________________________
    @objective(model, Max, sum( sum( sum(
                    ([p.feedin p.grid p.peer p.network p.tax p.eeg p.others] *p.matrix)[i] *X[h,i,n] for i=1:14) -
                    (100 *(V_hw_plus[h,n] +V_hw_minus[h,n] +T_fh_plus[h,n] +T_fh_minus[h,n]))  for h=1:m.h_predict) for n=1:sh.n_peers*sh.n_market));

    # Electricity demand, generation, market clearing___________________________________
    @constraints(model, begin
        [h=1:m.h_predict, n=1:sh.n_peers*sh.n_market],      sum(X[h,i,n] for i=[1,2,3,13]) == d_e[h];                                   # fulfill energy demand (== for max. self-consmption)
        [h=1:m.h_predict, n=1:sh.n_peers*sh.n_market],      sum(X[h,i,n] for i=[1,4,5,6,11]) /pv.eta_i == g_e[h,n];                     # restricted by PV generation
        [h=1:m.h_predict],                                  sum(sum(X[h,i,n] for i=[11,12]) for n=1:sh.n_peers*sh.n_market) ==
                                                                    sum(sum(X[h,i,n] for i=[13,14]) for n=1:sh.n_peers*sh.n_market);    # market clearing peer market
    end)
    # Battery__________________________________________________________________________
    @constraints(model, begin
        [h=1:m.h_predict-1, n=1:sh.n_peers*sh.n_market],    SOC_b[h+1,n] == ((1 -b.loss) *SOC_b[h,n])+
                                                                X[h,4,n] -sum(X[h,i,n] for i=[2,8,12]) /b.eta_b;            # State of Charge, loss for unique solutions
        [h=1:m.h_predict, n=1:sh.n_peers*sh.n_market],      b.soc_min <= SOC_b[h,n] <= b.soc_max;                           # Limits Battery usable capacity
        [h=1:m.h_predict, n=1:sh.n_peers*sh.n_market],      X[h,4,n] <= B_switch[h,n]*b.rate_max;                           # limit charging to nominal power (never at same time)
        [h=1:m.h_predict, n=1:sh.n_peers*sh.n_market],      sum(X[h,i,n] for i=[2,8,12]) <= (1-B_switch[h,n])*b.rate_max;   # limit discharging to nominal power (never at same time)
    end)
    # Heat pump_______________________________________________________________________________
    @constraints(model, begin
        [h=1:m.h_predict, n=1:sh.n_peers*sh.n_market],      sum(X[h,i,n] for i=[9,10]) ==
                                                                sum(X[h,i,n] for i=[6,7,8,14])                   # level power heat pump=and out (== for max. self-consmption)
        [h=1:m.h_predict, n=1:sh.n_peers*sh.n_market],      X[h,9,n] == Mod_fh[h,n] *hp.rate_max;                # heating energy FH max cap
        [h=1:m.h_predict, n=1:sh.n_peers*sh.n_market],      X[h,10,n] == Mod_hw[h,n] *hp.rate_max;               # heating energy HW max cap
        #[h=1:m.h_predict, n=1:sh.n_peers*sh.n_market],     Mod_hw[h,n] + Mod_fh[h,n] >= 0.1;                    # minimum level on?
        [h=1:m.h_predict, n=1:sh.n_peers*sh.n_market],      Mod_fh[h,n] <= 1 -HP_switch[h,n];                    # switch FH or HW
        [h=1:m.h_predict, n=1:sh.n_peers*sh.n_market],      Mod_hw[h,n] <= HP_switch[h,n];                       # switch HW or FH
    end)
    # Floor_heating__________________________________________________________________________________________
    @constraints(model, begin
        [h=1:m.h_predict-1, n=1:sh.n_peers*sh.n_market],    T_fh[h+1,n] == T_fh[h,n]+
                                                                (60*60)/(p_concr *fh.volume *c_concr)*
                                                                ((cop_fh[h] *X[h,9,n]) -d_fh[h]-
                                                                ((1-Hot[h]) *fh.loss) +(Hot[h] *fh.loss));       # SoC floor heating (temperature)
        [h=1:m.h_predict, n=1:sh.n_peers*sh.n_market],      T_fh[h,n] -((1 -Hot[h])*m.big) <= t_outside[h];      # force hot binary on if hotter outside than inside
        [h=1:m.h_predict, n=1:sh.n_peers*sh.n_market],      t_outside[h] -(Hot[h]*m.big) <= T_fh[h,n];
        [h=1:m.h_predict, n=1:sh.n_peers*sh.n_market],      T_fh[h,n] <= fh.soc_max +T_fh_plus[h,n];                # Limits temperature FH max
        [h=1:m.h_predict, n=1:sh.n_peers*sh.n_market],      fh.soc_min -T_fh_minus[h,n] <= T_fh[h,n];               # Limits temperature FH min
    end)
    # Hot water_____________________________________________________________________________________________
    @constraints(model, begin
        [h=1:m.h_predict-1, n=1:sh.n_peers*sh.n_market],    V_hw[h+1,n] == V_hw[h,n]+
                                                                (60*60)/((p_water *hw.t_supply *c_water)/1000)*
                                                                ((cop_hw[h] *X[h,10,n]) -d_hw[h] -hw.loss);         # SoC hot water (volume)
        [h=1:m.h_predict, n=1:sh.n_peers*sh.n_market],      V_hw[h,n] <= hw.soc_max +V_hw_plus[h,n];                # Limits volume HW max
        [h=1:m.h_predict, n=1:sh.n_peers*sh.n_market],      hw.soc_min - V_hw_minus[h,n] <= V_hw[h,n];              # Limits volume HW min

    end)
    # Peer market__________________________________________________________________________
    @constraints(model, begin
        [h=1:m.h_predict, n=1:sh.n_peers*sh.n_market],      sum(X[h,i,n] for i=[11,12]) <= Peer_switch[h,n]*M;             # Feed-in peer market
        [h=1:m.h_predict, n=1:sh.n_peers*sh.n_market],      sum(X[h,i,n] for i=[13,14]) <= (1-Peer_switch[h,n])*M;      # Purchase peer market
    end)


    JuMP.optimize!(model);

    # collect returns
    results = Array{Float64}(undef,(m.h_control*sh.n_peers*sh.n_market, 11+14+3+1));    # optimization variables + flows + month + day + hour
    for n=1:sh.n_peers*sh.n_market

        profits = sum( ([p.feedin p.grid p.peer p.network p.tax p.eeg p.others] *p.matrix)[i] .*JuMP.value.(X[1:m.h_control,i,n]) for i=1:14);

        results[((n-1)*m.h_control)+1:(n*m.h_control),:] =
            hcat(JuMP.value.(T_fh[1:m.h_control,n]), JuMP.value.(V_hw[1:m.h_control,n]), JuMP.value.(SOC_b[1:m.h_control,n]),
            JuMP.value.(T_fh_plus[1:m.h_control,n]), JuMP.value.(T_fh_minus[1:m.h_control,n]),
            JuMP.value.(V_hw_plus[1:m.h_control,n]), JuMP.value.(V_hw_minus[1:m.h_control,n]),
            profits,
            JuMP.value.(Peer_switch[1:m.h_control,n]),
            cop_fh[1:m.h_control], cop_hw[1:m.h_control], (ones(m.h_control)*(mod((div(n-1, sh.n_market)+1)-1,sh.n_peers)+1)),
            JuMP.value.(X[1:m.h_control,:,n]),                              # flow variables
            Matrix(df[sh.h_start:(sh.h_start + m.h_control -1), 13:15]));   # month + day + hour
    end

    return round.(JuMP.value.(SOC_b[m.h_control+1,:]), digits=5), JuMP.value.(T_fh[m.h_control+1,:]), JuMP.value.(V_hw[m.h_control+1,:]), results
end
