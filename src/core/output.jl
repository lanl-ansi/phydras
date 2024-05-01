
function update_solution_fields_in_ref(ss::SteadyOptimizer, var::Dict{Symbol,Any})
    
    sol = Dict{Symbol,Any}()

    ref = ss.ref
    nominal_values = ss.nominal_values

    sol[:pressure] = Dict()
    sol[:node_concentration] = Dict()
    sol[:node_decarbpremium] = Dict()
    sol[:node_calorific] = Dict()
    sol[:injection_flows] = Dict()
    sol[:withdrawal_flows] = Dict()
    sol[:pipe_flows] = Dict()
    sol[:compressor_flows] = Dict()
    sol[:pipe_concentration] = Dict()
    sol[:compressor_concentration] = Dict()
    sol[:compressor_ratio] = Dict()
    sol[:withdrawal_energy] = Dict()
    sol[:carbon_intensity] = Dict()
    sol[:objective_fn] = Dict()
    sol[:obj_fn_MR] = Dict()
    sol[:obj_fn_CEM] = Dict()
    sol[:obj_fn_GC] = Dict()
    sol[:total_decarbpremium] = Dict()
    sol[:total_co2] = Dict()
    sol[:total_co2][1] = 0
    sol[:total_ng] = Dict()
    sol[:total_h2] = Dict()

    for (i,_) in ref[:node]
        sol[:pressure][i] = sqrt(JuMP.value(var[:Π][i])) * nominal_values[:pressure]
        sol[:node_concentration][i] = JuMP.value(var[:η][i])
        sol[:node_calorific][i] = 141.8 * JuMP.value(var[:η][i]) + 44.2 * (1-JuMP.value(var[:η][i]))
    end

    for (i,_) in ref[:dispatchable_receipt]
        sol[:injection_flows][i] = JuMP.value(var[:qs][i]) * nominal_values[:mass_flow]
        η_s = ref[:dispatchable_receipt][i]["injection_conc"]
        sol[:total_co2][1] += JuMP.value(var[:qs][i]) * (1-η_s) * nominal_values[:mass_flow] * 44/16
    end

    for (i,delivery) in ref[:dispatchable_delivery]
        sol[:withdrawal_flows][i] = JuMP.value(var[:qw][i]) * nominal_values[:mass_flow]
        sol[:withdrawal_energy][i] = JuMP.value(var[:total_energy_withdrawal][i])
        η = JuMP.value(var[:η][delivery["node_id"]])
        sol[:carbon_intensity][i] = (JuMP.value(var[:qw][i]) * (1-η) * nominal_values[:mass_flow] * 44/16) / JuMP.value(var[:total_energy_withdrawal][i])
        sol[:total_ng][i] = JuMP.value(var[:qw][i]) * (1-η) * nominal_values[:mass_flow] 
        sol[:total_h2][i] = JuMP.value(var[:qw][i]) * (η) * nominal_values[:mass_flow] 
        sol[:node_decarbpremium][i] = CARBON_OFFSET * η * (141.8/44.2) * (44/16) / (141.8 * η + 44.2 * (1-η))
    end
    sol[:total_decarbpremium] = sum(sol[:node_decarbpremium][i] for i = 1:length(ref[:dispatchable_delivery]))

    for (i,pipe) in ref[:pipe]
        sol[:pipe_flows][i] = JuMP.value(var[:f_pipe][i]) * nominal_values[:mass_flow]
        sol[:pipe_concentration][i] = JuMP.value(var[:γ_pipe][i])
    end

    for (i,compressor) in ref[:compressor]
        sol[:compressor_flows][i] = JuMP.value(var[:f_comp][i]) * nominal_values[:mass_flow]
        sol[:compressor_concentration][i] = JuMP.value(var[:γ_comp][i])
        sol[:compressor_ratio][i] = sqrt(JuMP.value(var[:ω][i]))
    end

    # De-tangle the objective value
    load_shed = []
    emissions_cost = []
    comp_cost = []
    T = 288.706
    for (i, receipt) in ref[:dispatchable_receipt]
        push!(
            load_shed,
            -receipt["offer_price_H2"] * JuMP.value(var[:qs][i]) * receipt["injection_conc"] - 
            receipt["offer_price_NG"] * JuMP.value(var[:qs][i]) * (1 - receipt["injection_conc"])
        )
    end
    for (i, delivery) in ref[:dispatchable_delivery]
        if i == 4 || i == 26 || i == 23 || i == 17             # nodeids 12, 37, 17, 16
            push!(
                load_shed,
                BIDPRICEX * JuMP.value(var[:qw][i]) * (141.8 * JuMP.value(var[:η][delivery["node_id"]]) + 
                44.2 * (1 - JuMP.value(var[:η][delivery["node_id"]])))
            )
        else
            push!(
                load_shed,
                delivery["bid_price_MJ"] * JuMP.value(var[:qw][i]) * (141.8 * JuMP.value(var[:η][delivery["node_id"]]) + 
                44.2 * (1 - JuMP.value(var[:η][delivery["node_id"]])))
            )
        end
    end
    for (i, delivery) in ref[:dispatchable_delivery]
        push!(
            emissions_cost,
            CARBON_OFFSET * JuMP.value(var[:qw][i]) * JuMP.value(var[:η][delivery["node_id"]]) * 141.8/44.2 * 44/16
        )
    end
    η = 0.13/3600 # $ per kw-s
    for (i,compressor) in ref[:compressor]
        Π_to = JuMP.value(var[:Π][compressor["to_node"]])
        Π_fr = JuMP.value(var[:Π][compressor["fr_node"]])
        γ_comp = JuMP.value(var[:γ_comp][i])
        κ = 1.405 * γ_comp + 1.303 * (1 - γ_comp)
        G = 0.0696 * γ_comp + 0.6 * (1 - γ_comp)
        push!(
            comp_cost,
            η * (T * 286.76 * (κ - 1)) / (G * κ) * ((Π_to/Π_fr)^((κ - 1) / κ) - 1) * abs(JuMP.value(var[:f_comp][i]))
        )
    end
    sum_load_shed = sum(load_shed[i] for i = 1:length(load_shed)) * nominal_values[:mass_flow]
    sum_emissions_cost = sum(emissions_cost[i] for i = 1:length(emissions_cost)) * nominal_values[:mass_flow]
    sum_compressor_cost = sum(comp_cost[i] for i = 1:length(comp_cost)) * nominal_values[:mass_flow]
    sol[:objective_fn] = sum_load_shed + sum_emissions_cost - sum_compressor_cost
    sol[:obj_fn_MR] = sum_load_shed
    sol[:obj_fn_CEM] = sum_emissions_cost
    sol[:obj_fn_GC] = sum_compressor_cost

    return sol

end

