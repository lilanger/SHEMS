function SHEMS_optimizer_seco(sh, hp, fh, hw, b, m, bc_violations)
    flows = [:PV_DE, :B_DE, :GR_DE, :PV_B, :PV_GR, :PV_HP, :GR_HP, :B_HP, :HP_FH, :HP_HW];
    p_concr = 2400.0;   #kg/m^3
    c_concr = 1.0;      #kJ/(kg*°C)
    p_water = 997.0;    #kg/m^3
    c_water = 4.184;    #kJ/(kg*°C)

    # Input data__________________________________________________________________________________________________________________________________________________________
    df = CSV.read("data/200124_datafile_all_details_right_timestamp.csv",DataFrame);
    h_last = sh.h_start + m.h_predict -1;                     # optimization horizon

    # all peers have the same demand
    d_e =  df[sh.h_start:h_last,:electkwh];                     # electricity demand 1 year from BeOpt
    d_fh = df[sh.h_start:h_last,:heatingkwh];                  # heating demand 1 year from BeOpt
    d_hw = df[sh.h_start:h_last,:hotwaterkwh];                 # hot water demand 1 year from BeOpt
    g_e =  df[sh.h_start:h_last,:PV_generation];                # electricity generation (from Renewable ninjas)
    t_outside = df[sh.h_start:h_last,:Temperature];            # °C (from Renewable ninjas)

    # Calculate coefficients of performance for every time period (1:h_predict)___________________________________________
    cop_fh = COPcalc(fh, t_outside);
    cop_hw = COPcalc(hw, t_outside);

    # Model start________________________________________________________________________________________________________________________________________________________
    #Define Model und Solver and settings
    #model = Model(optimizer_with_attributes(() -> Gurobi.Optimizer(GUROBI_ENV)));
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
        X[1:m.h_predict, 1:length(flows)] >= 0;    #1:PV_DE, 2:B_DE, 3:GR_DE, 4:PV_B, 5:PV_GR, 6:PV_HP, 7:GR_HP, 8:B_HP, 9:HP_FH, 10:HP_HW
        SOC_b[1:m.h_predict]  >= 0;
        B_switch[1:m.h_predict], Bin;
        T_fh[1:m.h_predict] >= 0; V_hw[1:m.h_predict] >= 0;
        Mod_fh[1:m.h_predict] >= 0; Mod_hw[1:m.h_predict]   >= 0;
        T_fh_plus[1:m.h_predict] >= 0; T_fh_minus[1:m.h_predict] >= 0; V_hw_plus[1:m.h_predict] >= 0; V_hw_minus[1:m.h_predict] >= 0;
        HP_switch[1:m.h_predict], Bin;
        Hot[1:m.h_predict], Bin;
    end)

    # Fix start SoCs
    fix.(SOC_b[1], sh.soc_b; force=true);
    fix.(T_fh[1],sh.soc_fh; force=true);
    fix.(V_hw[1],sh.soc_hw; force=true);

    #1:PV_DE, 2:B_DE, 3:GR_DE, 4:PV_B, 5:PV_GR, 6:PV_HP, 7:GR_HP, 8:B_HP, 9:HP_FH, 10:HP_HW
    # Objective function: maximize self-consumption _____________________________________________________________________
    @objective(model, Min, sum(X[h,5] +
        (sh.costfactor *(T_fh_plus[h] +T_fh_minus[h] +V_hw_plus[h] +V_hw_minus[h])) for h=1:m.h_predict));

    # Self-consumption: Comfort violations according to base case
    @constraint(model, SeCo_comfort, sum(T_fh_plus[h] + T_fh_minus[h] + V_hw_plus[h] + V_hw_minus[h] for h in 1:m.h_predict) <= bc_violations);

    # Electricity demand, generation, market clearing___________________________________
    @constraints(model, begin
        [h=1:m.h_predict],     sum(X[h,i] for i=[1,2,3]) == d_e[h];                     # fulfill energy demand
        [h=1:m.h_predict],     sum(X[h,i] for i=[1,4,5,6]) == g_e[h];                   # restricted by PV generation
    end)
    # Battery__________________________________________________________________________
    @constraints(model, begin
        [h=1:m.h_predict-1],   SOC_b[h+1] == ((1 -b.loss) *SOC_b[h])+
                                    (b.eta *X[h,4]) -sum((1/(b.eta)) *X[h,i] for i=[2,8]);    # State of Charge, loss for unique solutions
        [h=1:m.h_predict],     b.soc_min <= SOC_b[h] <= b.soc_max;                            # Limits Battery usable capacity
        [h=1:m.h_predict],     X[h,4] <= B_switch[h]*b.rate_max;                              # Either charging
        [h=1:m.h_predict],     sum(X[h,i] for i=[2,8]) <= (1-B_switch[h])*b.rate_max;         # or discharging
    end)
    # Heat pump_______________________________________________________________________________
    @constraints(model, begin
        [h=1:m.h_predict],     sum(X[h,i] for i=[9,10]) == sum(X[h,i] for i=[6,7,8]);         # level power heat pump=and out
        [h=1:m.h_predict],     X[h,9] == Mod_fh[h] *hp.rate_max;                              # heating energy FH max cap
        [h=1:m.h_predict],     X[h,10] == Mod_hw[h] *hp.rate_max;                             # heating energy HW max cap
        [h=1:m.h_predict],     Mod_fh[h] <= 1 -HP_switch[h];                                  # switch FH or HW
        [h=1:m.h_predict],     Mod_hw[h] <= HP_switch[h];                                     # switch HW or FH
    end)
    # Floor_heating__________________________________________________________________________________________
    @constraints(model, begin
        [h=1:m.h_predict-1],   T_fh[h+1] == T_fh[h]+
                                    (60*60)/(p_concr *fh.volume *c_concr) *
                                    ((cop_fh[h] *X[h,9]) -d_fh[h] -
                                    ((1-Hot[h]) *fh.loss) +(Hot[h] *fh.loss));      # SoC floor heating (temperature)
        [h=1:m.h_predict],     T_fh[h] - ((1 -Hot[h]) *m.big) <= t_outside[h];     # force hot binary on if hotter outside than inside
        [h=1:m.h_predict],     t_outside[h] -(Hot[h] *m.big) <= T_fh[h];
        [h=1:m.h_predict],     T_fh[h] <= fh.soc_max +T_fh_plus[h];                # Limits temperature FH max
        [h=1:m.h_predict],     fh.soc_min -T_fh_minus[h] <= T_fh[h];               # Limits temperature FH min
    end)
    #Hot water_____________________________________________________________________________________________
    @constraints(model, begin
        [h=1:m.h_predict-1],   V_hw[h+1] == V_hw[h]+
                                    (60*60)/((p_water *hw.t_supply *c_water)/1000) *
                                    ((cop_hw[h] *X[h,10]) -d_hw[h] -hw.loss);       # SoC hot water (volume)
        [h=1:m.h_predict],     V_hw[h] <= hw.soc_max +V_hw_plus[h];                # Limits volume HW max
        [h=1:m.h_predict],     hw.soc_min - V_hw_minus[h] <= V_hw[h];              # Limits volume HW min
    end)

    JuMP.optimize!(model);

    # collect returns
    profits = (sh.p_sell .*JuMP.value.(X[1:m.h_control,5])) .-sh.p_buy .*(JuMP.value.(X[1:m.h_control,3]) .+ JuMP.value.(X[1:m.h_control,7]));

    results = hcat(JuMP.value.(T_fh[1:m.h_control]), JuMP.value.(V_hw[1:m.h_control]), JuMP.value.(SOC_b[1:m.h_control]),
                    JuMP.value.(V_hw_plus[1:m.h_control]), JuMP.value.(V_hw_minus[1:m.h_control]),
                    JuMP.value.(T_fh_plus[1:m.h_control]), JuMP.value.(T_fh_minus[1:m.h_control]),
                    profits, cop_fh[1:m.h_control], cop_hw[1:m.h_control],
                    JuMP.value.(X[1:m.h_control, :]),                                               # flow variables
                    Matrix(df[sh.h_start:(sh.h_start + m.h_control -1), 13:15]));                   # month + day + hour

    if m.rolling_flag==1
        return JuMP.value.(SOC_b[m.h_control+1]), JuMP.value.(T_fh[m.h_control+1]), JuMP.value.(V_hw[m.h_control+1]), results
    else
        return results
    end
end
