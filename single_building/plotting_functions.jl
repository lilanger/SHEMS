function bar_PV(Data_df, date)
    # bars
    @df Data_df[(Data_df[:,:day].==Dates.day(date)) .&(Data_df[:,:month].==Dates.month(date)),:] groupedbar(
        [:PV_HP :PV_GR :PV_B :PV_DE], color =[:firebrick :grey :purple :orange],
        ylim=(0,15), yticks=0:5:15, xticks=0:6:24,
        annotations=(2,12, text("$(Dates.month(date))/$(Dates.day(date))", 10)), legendfontsize=6,
        label=["PV_HP" "PV_GR" "PV_B" "PV_DE"], legend=false, bar_position = :stack, alpha=0.8);
    # battery cap
    @df Data_df[(Data_df[:,:day].==Dates.day(date)) .&(Data_df[:,:month].==Dates.month(date)),:] plot!(
        [:Soc_B], color =[:purple], ylim=(0,15), yticks=0:2:15, xticks=0:6:24,
        label=["SOC_b"], legend=false, linewidth= 2.0);
    # PV generation
    @df Data_df[(Data_df[:,:day].==Dates.day(date)) .&(Data_df[:,:month].==Dates.month(date)),:] plot!(
        [:PV_generation], ylim=(0,15), yticks=0:5:15, xticks=0:6:24, color =[:gold],
        label=["g_e"], legend=false, linewidth= 2.0);

    plot!(0:23, ones(24,1)*13.5, linestyle=:dot, linewidth= 2, color=:purple)
end

function bar_demand(Data_df, date)
    # bars
    @df Data_df[(Data_df[:,:day].==Dates.day(date)) .&(Data_df[:,:month].==Dates.month(date)),:] groupedbar(
        [:B_DE :GR_DE :PV_DE ], color =[:purple :grey :gold],
        ylim=(0,2), yticks=0:0.5:2, xticks=0:6:24,
        annotations=(2,1.8, text("$(Dates.month(date))/$(Dates.day(date))", 10)), legendfontsize=6,
        label=["B_DE" "GR_DE" "PV_DE"], legend=false, bar_position = :stack, alpha=0.8);
    # electricity demand
    @df Data_df[(Data_df[:,:day].==Dates.day(date)) .&(Data_df[:,:month].==Dates.month(date)),:] plot!(
        [:electkwh], ylim=(0,2), yticks=0:0.5:2, xticks=0:6:24, color =[:orange],
        label=["d_e"], legend=false, linewidth= 2.0);

    plot!(0:23, ones(24,1)*13.5, linestyle=:dash, color=:purple)
end

function bar_heat(Data_df, date)
    # hot water demand
    @df Data_df[(Data_df[:,:day].==Dates.day(date)) .&(Data_df[:,:month].==Dates.month(date)),:] plot(
        [:hotwaterkwh]+[:heatingkwh], fillrange=[:heatingkwh], ylim=(0,15), yticks=0:5:15, xticks=0:6:24,
        color =[:steelblue], label=["d_fh"], legend=false, alpha=0.2);
    # heat demand
    @df Data_df[(Data_df[:,:day].==Dates.day(date)) .&(Data_df[:,:month].==Dates.month(date)),:] plot!(
        [:heatingkwh], fillrange=zeros(24), ylim=(0,15), yticks=0:5:15, xticks=0:6:24,
        color =[:firebrick], label=["d_fh"], legend=false, alpha=0.2);
    # bars
    @df Data_df[(Data_df[:,:day].==Dates.day(date)) .&(Data_df[:,:month].==Dates.month(date)),:] groupedbar!(
        [:B_HP :GR_HP :PV_HP], color =[:purple :grey :gold],
        ylim=(0,15), yticks=0:5:15, xticks=0:6:24,
        annotations=(2, 14, text("$(Dates.month(date))/$(Dates.day(date))", 10)), legendfontsize=6,
        label=["B_DE" "GR_DE" "PV_DE"], legend=false, bar_position = :stack, alpha=0.8);

    plot!(0:23, ones(24,1)*3, linestyle=:dot, linewidth= 2, color=:grey)
end

function bar_comfort(Data_df, date)
    @df Data_df[(Data_df[:,:day].==Dates.day(date)) .&(Data_df[:,:month].==Dates.month(date)),:] groupedbar(
        ([:HP_FH :HP_HW].>0.005)*200, color =[:firebrick :steelblue],
        ylim=(19,23), yticks=20:1:22, xticks=0:6:24,
        annotations=(2, 22.5, text("$(Dates.month(date))/$(Dates.day(date))", 10)), legendfontsize=6,
        label=["Mod_fh" "Mod_hw"], legend=false, bar_position = :stack, alpha=0.15);

    # state-of-charge fh
    @df Data_df[(Data_df[:,:day].==Dates.day(date)) .&(Data_df[:,:month].==Dates.month(date)),:] plot!(
        [:Temp_FH], ylim=(19,23), yticks=20:1:22, xticks=0:6:24, color =[:firebrick],
        label=["T_fh"], legend=false, linewidth= 2.0);

    plot!(0:23, ones(24,1)*20, linestyle=:dot, linewidth= 2, color=:firebrick)
    plot!(0:23, ones(24,1)*22, linestyle=:dot, linewidth= 2, color=:firebrick)

    plt = twinx()
    # state-of-charge hw
    @df Data_df[(Data_df[:,:day].==Dates.day(date)) .&(Data_df[:,:month].==Dates.month(date)),:] plot!(
        plt, [:Vol_HW], ylim=(10,190), yticks=20:40:180, xticks=0:6:24, color =[:steelblue],
        label=["V_fh"], legend=false, linewidth= 2.0, linestyle=:dash, grid=false);

    plot!(plt, 0:23, ones(24,1)*20, linestyle=:dot, linewidth= 2, color=:steelblue)
    plot!(plt, 0:23, ones(24,1)*180, linestyle=:dot, linewidth= 2, color=:steelblue)
end

function bar_row(plotfunction, Data_df, date, length)
    plot([plotfunction(Data_df, (date+Day(i-1))) for i in 1:length]..., layout=(1,length), size=(300*length,200));
end
