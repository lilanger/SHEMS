

# load all input and result data into a dataframe-----------------------------------------------------------
function load_data(date, h_predict, h_control, h_start, h_end, market_flag, n_peers, n_market, case)
    Input_df = CSV.read("data/200124_datafile_all_details_right_timestamp.csv");
    Flow_df = CSV.read("results/$(date)_results_$(h_predict)_$(h_control)_$(h_start)-$(h_end)"*
                    "_$(market_flag)_$(n_peers)_$(n_market)_$(case).csv");
    # merge on data stamp
    Data_df = leftjoin(Flow_df, Input_df, on=[:month, :day, :hour], makeunique=false,
                        indicator=nothing, validate=(false, false));
    return Data_df
end

# short caller for latest data + standard setup-----------------------------------------------------------
function load_case(case, number_of_peers)
    return load_data(200829, 36, 12, 1, 8760, 1, number_of_peers, 1, case);
end

# bar chart for PV flows----------------------------------------------------------------------------
function bar_PV(Data_df, date, peer, yaxis, title)
        # PV generation
    @df Data_df[(Data_df[:,:day].==Dates.day(date)) .&(Data_df[:,:month].==Dates.month(date)) .&(Data_df[:,:Peer].==peer),:] plot(
        [:PV_generation], xticks=0:6:24, yticks=-4:2:10, tickfontsize=10, ylim=(-4,11), color =[:gold], 
        label=["g_e"], legend=false, legendfontsize=8, linewidth= 3.0, title="$(title)", titlefontsize=11, 
        titlelocation=:left);
    
       plot!(0:23, ones(24,1)*10.0, linestyle=:dot, linewidth= 2, color=:purple)
    
    # bars PV
    @df Data_df[(Data_df[:,:day].==Dates.day(date)) .&(Data_df[:,:month].==Dates.month(date)) .&(Data_df[:,:Peer].==peer),:] groupedbar!(
        [:PV_PM :PV_HP :PV_GR :PV_B :PV_DE], color =[:green :firebrick :grey :purple :orange],
        label=["→ pm" "→ hp" "→ gr" "→ b" "→ de"], legend=false, bar_position = :stack, alpha=0.8);
    
    # bars B
    @df Data_df[(Data_df[:,:day].==Dates.day(date)) .&(Data_df[:,:month].==Dates.month(date)) .&(Data_df[:,:Peer].==peer),:] groupedbar!((-1) .*[:B_PM :B_HP :B_DE], color =[:green :firebrick :orange],
        label=[], bar_position = :stack, alpha=0.8);
    
    # battery cap
    @df Data_df[(Data_df[:,:day].==Dates.day(date)) .&(Data_df[:,:month].==Dates.month(date)) .&(Data_df[:,:Peer].==peer),:] plot!(
        [:SOC_B], color =[:purple], xticks=0:6:24,
        label=["SOC_b"], linewidth= 2.0);
    
    yaxis!("$(yaxis)", font(10, "sans-sarif"), tickfontsize=10)
    annotate!(3, 8.5, text("$(Dates.month(date))/$(Dates.day(date))", 10))
end

# bar chart for demand fulfillment-----------------------------------------------------------------
function bar_demand(Data_df, date, peer, yaxis, title)
    # bars
    @df Data_df[(Data_df[:,:day].==Dates.day(date)) .&(Data_df[:,:month].==Dates.month(date)) .&(Data_df[:,:Peer].==peer),:] groupedbar(
        [:PM_DE :B_DE :GR_DE :PV_DE ], color =[:green :purple :grey :gold],
        ylim=(0,2.2), yticks=0:0.5:2, xticks=0:6:24, legendfontsize=6,
        label=["PM_DE" "B_DE" "GR_DE" "PV_DE"], legend=false, bar_position = :stack, alpha=0.8, title="$(title)", 
        titlefontsize=11, titlelocation=:left);
    
    # electricity demand
    @df Data_df[(Data_df[:,:day].==Dates.day(date)) .&(Data_df[:,:month].==Dates.month(date)) .&(Data_df[:,:Peer].==peer),:] plot!(
        [:electkwh], color =[:orange],
        label=["d_e"], linewidth= 2.0);
    
    yaxis!("$(yaxis)", font(10, "sans-sarif"), tickfontsize=10)
end

# chart for heat/ hot water demand fulfillment-----------------------------------------------------------
function bar_heat(Data_df, date, peer, yaxis, title)
    # hot water demand
    @df Data_df[(Data_df[:,:day].==Dates.day(date)) .&(Data_df[:,:month].==Dates.month(date)) .&(Data_df[:,:Peer].==peer),:] plot(
        [:hotwaterkwh]+[:heatingkwh], fillrange=[:heatingkwh], yticks=0:2:10, ylim=(0,11), xticks=0:6:24,          
        tickfontsize=10, color =[:steelblue], label=["d_fh"], legend=false, alpha=0.2, title="$(title)", 
        titlefontsize=11, titlelocation=:left);
    # heat demand
    @df Data_df[(Data_df[:,:day].==Dates.day(date)) .&(Data_df[:,:month].==Dates.month(date)) .&(Data_df[:,:Peer].==peer),:] plot!(
        [:heatingkwh], fillrange=zeros(24),
        color =[:firebrick], label=["d_fh"], alpha=0.2);
    # bars
    @df Data_df[(Data_df[:,:day].==Dates.day(date)) .&(Data_df[:,:month].==Dates.month(date)) .&(Data_df[:,:Peer].==peer),:] groupedbar!(
        [:PM_HP :B_HP :GR_HP :PV_HP], color =[:green :purple :grey :gold],
        label=["PM_DE" "B_DE" "GR_DE" "PV_DE"], bar_position = :stack, alpha=0.8);

    plot!(0:23, ones(24,1)*3, linestyle=:dot, linewidth= 2, color=:grey)
    yaxis!("$(yaxis)", font(10, "sans-sarif"))
end

# chart for comfort ranges for heat/ hot water----------------------------------------------------------
function bar_comfort(Data_df, date, peer, yaxis, title)
    @df Data_df[(Data_df[:,:day].==Dates.day(date)) .&(Data_df[:,:month].==Dates.month(date)) .&(Data_df[:,:Peer].==peer),:] groupedbar(
        ([:HP_FH :HP_HW].>0.005)*200, color =[:firebrick :steelblue],
        ylim=(19,23), yticks=20:1:22, xticks=0:6:24, tickfontsize=10, legendfontsize=6,
        label=["Mod_fh" "Mod_hw"], legend=false, bar_position = :stack, alpha=0.15, title="$(title)", titlefontsize=11, 
        titlelocation=:left);

    # state-of-charge fh
    @df Data_df[(Data_df[:,:day].==Dates.day(date)) .&(Data_df[:,:month].==Dates.month(date)) .&(Data_df[:,:Peer].==peer),:] plot!(
        [:Temp_FH], ylim=(19,23), yticks=20:1:22, xticks=0:6:24, tickfontsize=10, color =[:firebrick], 
        label=["T_fh"], legend=false, linewidth= 2.0);

    plot!(0:23, ones(24,1)*20, linestyle=:dot, linewidth= 2, color=:firebrick)
    plot!(0:23, ones(24,1)*22, linestyle=:dot, linewidth= 2, color=:firebrick)
    yaxis!("$(yaxis)", font(10, "sans-sarif"))

    plt = twinx()
    # state-of-charge hw
    @df Data_df[(Data_df[:,:day].==Dates.day(date)) .&(Data_df[:,:month].==Dates.month(date)) .&(Data_df[:,:Peer].==peer),:] plot!(
        plt, [:Vol_HW], ylim=(10,190), yticks=20:40:180, xticks=0:6:24, tickfontsize=10, color =[:steelblue],
        label=["V_fh"], legend=false, linewidth= 2.0, linestyle=:dash, grid=false);

    plot!(plt, 0:23, ones(24,1)*20, linestyle=:dot, linewidth= 2, color=:steelblue)
    plot!(plt, 0:23, ones(24,1)*180, linestyle=:dot, linewidth= 2, color=:steelblue)
    xaxis!("time")
end

function plot_legend(plotfunction)
    if plotfunction == bar_PV
        scatter((1:5)', xlim=(4,5), color =[:green :firebrick :grey :purple :orange], legend=(.45,.9),
            label=["→pm" "→hp" "→gr" "→b" "→d_e"], framestyle= :none, marker= (:rect, stroke(0)), legendfontsize=10)   
        plot!((1:3)', xlim=(4,5), linestyle=[:solid :solid :dot], color=[:gold :purple :purple], 
            label=["ge" "SOC_b" "b_max"])
    
        elseif plotfunction == bar_demand
        scatter((1:4)', xlim=(4,5), color =[:green :grey :purple :gold], legend=(.45,.5),
            label=["pm→d_e" "gr→d_e" "b→d_e" "pv→d_e"], framestyle= :none, marker= (:rect, stroke(0)), 
            legendfontsize=10)   
        plot!((1:1)', xlim=(4,5), linestyle=[:solid], color=:orange, label="de")  
    
        elseif plotfunction == bar_heat
        scatter((1:6)', xlim=(4,5), color =[:green :grey :purple :gold :firebrick :steelblue], legend=(.45,.8),
            label=["pm→hp" "gr→hp" "b→hp" "pv→hp" "d_fh" "d_hw"], framestyle= :none, marker= (:rect, stroke(0)),
            legendfontsize=10, alpha=[1 1 1 1 .2 .2])   
        plot!((1:1)', xlim=(4,5), linestyle=[:dot], color=:grey, label="hp_max")   
    
        elseif plotfunction == bar_comfort
        scatter((1:2)', xlim=(4,5), color =[:firebrick :steelblue], legend=(.45,.7),
            label=["mod_fh" "mod_hw"], framestyle= :none, marker= (:rect, stroke(0)),
            legendfontsize=10, alpha=[.2 .2])   
        plot!((1:4)', xlim=(4,5), linestyle=[:dot :dot :solid :dash], 
            color=[:firebrick :steelblue :firebrick :steelblue], label=["range_fh" "range_hw" "T_fh" "V_hw"])      
    end
end    


# combine plots in rows-----------------------------------------------------------------------------
function bar_row(plotfunction, Data_df, date, peer, yaxis, title, length)
    plot(plotfunction(Data_df, date, peer, yaxis, title), [plotfunction(Data_df, (date+Day(i-1)), peer, "", "")
            for i in 2:length]..., plot_legend(plotfunction),layout=grid(1,length+1, 
            widths=vcat([((length-.55)/length/length) for i in 1:length], [.55*length/length/length])), 
            size=(300*(length+1),200), foreground_color_legend = :transparent, background_color_legend= :transparent); 
end

#KPI functions-----------------------------------------------------------------------------------------
function calc_energy_use(Data_df, n_peers)
    return convert.(Int64, round.([ sum(sum(groupby(Data_df, "Peer")[i][!,j] for j in ["PV_DE", "B_DE", "GR_DE", "HP_FH", "HP_HW", "PM_DE"])) for i in 1:n_peers], digits=0))
end


function peer_cons(n_peers)
    multiplier = [100, 100]
    if n_peers >= 2
        for i in 1:(n_peers-2)
            append!(multiplier, 0)
        end
    end
    return multiplier
end
    

function calc_self_consumption(Data_df, n_peers)
    return convert.(Int64, round.(peer_cons(n_peers) .*[1 - (sum(sum(groupby(Data_df, "Peer")[i][!,j] for j in ["PV_GR", "PV_PM", "B_PM"])) / sum(groupby(Data_df, "Peer")[i][!,"PV_generation"])) for i in 1:n_peers], digits=0))
end


function calc_self_sufficiency(Data_df, n_peers)
    return convert.(Int64, round.(100 .*(1 .- [sum(sum(groupby(Data_df, "Peer")[i][!,j] for j in ["GR_DE", "GR_HP", "PM_DE", "PM_HP"])) for i in 1:n_peers] ./ calc_energy_use(Data_df, n_peers)), digits=0)) 
end


function calc_comfort_violations(Data_df, n_peers)
    return convert.(Int64, round.([sum(sum(groupby(Data_df, "Peer")[i][!,j] for j in ["V_HW_plus", "V_HW_minus", "T_FH_plus", "T_FH_minus"])) for i in 1:n_peers], digits=0)) 
end


function calc_profit(Data_df, n_peers)
    return convert.(Int64, round.([sum(groupby(Data_df, "Peer")[i][!,"profits"]) for i in 1:n_peers]./100, digits=0)) 
end


function calc_levies(case, n_peers)
    return hcat([collect( sum([9.87, 12.19,  24.39, 7.71, 2.05, 6.756, 2.667] .*Matrix(CSV.read("data/tariff_matrix_case_$(case).csv")) *Matrix(groupby(load_case(case, n_peers), "Peer")[i][!,13:26])', dims=2)./100) for i in 1:n_peers]...)
end

function calc_shares(case, n_peers)
    return hcat([collect( sum(Matrix(CSV.read("data/flow_matrix.csv")) *Matrix(groupby(load_case(case, n_peers), "Peer")[i][!,13:26])', dims=2)) for i in 1:n_peers]...)
end


