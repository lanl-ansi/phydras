
"Constraint:Energy Withdrawal Constraint Optimized"
function constraint_energy_withdraw!(model,nw,var,con)
    con[:energy_withdrawal] = Dict()
    var[:total_energy_withdrawal] = Dict()

    η = var[:η]
    qw = var[:qw]
    nominal_massflow = nw[:nominal_massflow]
    
    for (i, node) in nw[:node]
        for j in nw[:dispatchable_deliveries_in_node][i]
            var[:total_energy_withdrawal][j] = ((141.8 * η[i] * qw[j]) + (44.2 * (1-η[i]) * qw[j])) * nominal_massflow
            total_energy_withdrawn = var[:total_energy_withdrawal][j]

            # if j != OP_NODE # optimized demand
            #     con[:energy_withdrawal][j] =
            #         JuMP.@constraint(model, total_energy_withdrawn <= G_MAX_OP )
            # else # constant demand
            #     con[:energy_withdrawal][j] =
            #         JuMP.@constraint(model, total_energy_withdrawn == G_MAX_FX )
            # end
            con[:energy_withdrawal][j] =
                    JuMP.@constraint(model, total_energy_withdrawn <= G_MAX_OP )
        end
    end

    return
end

"Constraint:Minimum Withdrawn Hydrogen Concentration"
function constraint_withdrawal_conc!(model,nw,var,con)
    con[:min_withdrawal_conc] = Dict()

    η = var[:η]

    for (i,node) in nw[:node]
        for j in nw[:dispatchable_deliveries_in_node][i]
            con[:min_withdrawal_conc][j] = 
                JuMP.@constraint(model, η[i] >= CONC_MIN)
        end
    end

    return
end

"Constraint:Pipe Pressure Drop"
function constraint_pipe_pressure!(model,nw,var,con,params)
    con[:pipe_physics] = Dict()

    Π = var[:Π]
    f_pipe = var[:f_pipe]
    γ_pipe = var[:γ_pipe]
    
    for (i, pipe) in nw[:pipe]
        Π_fr = Π[pipe["fr_node"]]
        Π_to = Π[pipe["to_node"]]
        f = f_pipe[i]
        γ = γ_pipe[i]
        resistance = pipe["resistance"] / (pipe["area"]^2)
        
        multiplier = nw[:multiplier] * (672^2)
        a_h2 = params[:speed_h2]
        a_ng = params[:speed_ng]

        V = (a_h2^2 * γ + a_ng^2 * (1 - γ)) / (672^2)

        con[:pipe_physics][i] =
            JuMP.@NLconstraint(model, Π_fr - Π_to == resistance * multiplier * V * f * abs(f))
    end

    return
end

"Constraint:Compressor Pressure"
function constraint_compressor_pressure!(model,nw,var,con)
    nominal_pressure = nw[:nominal_pressure]
    con[:compressor_boost] = Dict()
    con[:compressor_boost_max] = Dict()

    Π = var[:Π]
    ω = var[:ω]

    for (i, compressor) in nw[:compressor]
        Π_fr = Π[compressor["fr_node"]]
        Π_to = Π[compressor["to_node"]]
        ω_comp = ω[i]
        
        # ω_max = nw[:compressor][i]["c_ratio_max"]^2 

        con[:compressor_boost][i] = 
            JuMP.@NLconstraint(model, Π_to == ω_comp * Π_fr)
        con[:compressor_boost_max][i] = 
            JuMP.@NLconstraint(model, Π_to <= (nw[:node][compressor["to_node"]]["p_max"])^2)
        # con[:compressor_boost_le][i] = 
        #     JuMP.@constraint(model, Π_to - ω_max * Π_fr <= 0)
        # con[:compressor_boost_ge][i] = 
        #     JuMP.@constraint(model, Π_to - Π_fr >= 0)

    end

    return
end

# "Constraint:Node mass flow balance"
# function constraint_mass_flow_balance!(model,nw,var,con)
#     con[:nodal_mass_flow_balance] = Dict()
#     var[:net_nodal_injection] = Dict()
#     var[:net_nodal_edge_out_flow] = Dict()

#     qs = var[:qs]
#     qw = var[:qw]
#     f_pipe = var[:f_pipe]
#     f_comp = var[:f_comp]

#     for (i, node) in nw[:node]
#         var[:net_nodal_injection][i] = 0
#         for j in nw[:dispatchable_receipts_in_node][i]
#             var[:net_nodal_injection][i] += qs[j]
#         end
#         for j in nw[:dispatchable_deliveries_in_node][i]
#             var[:net_nodal_injection][i] -= qw[j]
#         end
#     end

#     for (i, node) in nw[:node]
#         var[:net_nodal_edge_out_flow][i] = 0
#         for j in nw[:outgoing_pipes][i]
#             var[:net_nodal_edge_out_flow][i] += f_pipe[j]
#         end
#         for j in nw[:outgoing_compressors][i]
#             var[:net_nodal_edge_out_flow][i] += f_comp[j]
#         end
#         for j in nw[:incoming_pipes][i]
#             var[:net_nodal_edge_out_flow][i] -= f_pipe[j]
#         end
#         for j in nw[:incoming_compressors][i]
#             var[:net_nodal_edge_out_flow][i] -= f_comp[j]
#         end
#     end

#     for (i, node) in nw[:node]
#         net_injection = var[:net_nodal_injection][i]
#         net_nodal_edge_out_flow = var[:net_nodal_edge_out_flow][i]
#         con[:nodal_mass_flow_balance][i] =
#             JuMP.@constraint(model, net_nodal_edge_out_flow - net_injection == 0)
#     end

#     return
# end

"Constraint:Node H2 mass flow balance"
function constraint_h2_mass_flow_balance!(model,nw,var,con)
    con[:nodal_h2_mass_flow_balance] = Dict()
    var[:net_h2_nodal_injection] = Dict()
    var[:net_h2_nodal_edge_out_flow] = Dict()

    qs = var[:qs]
    qw = var[:qw]
    f_pipe = var[:f_pipe]
    f_comp = var[:f_comp]
    η = var[:η]
    γ_pipe = var[:γ_pipe]
    γ_comp = var[:γ_comp]

    for (i,node) in nw[:node]
        var[:net_h2_nodal_injection][i] = 0
        for j in nw[:dispatchable_receipts_in_node][i]
            η_s = nw[:dispatchable_receipt][j]["injection_conc"]
            var[:net_h2_nodal_injection][i] += η_s * qs[j]
        end
        for j in nw[:dispatchable_deliveries_in_node][i]
            var[:net_h2_nodal_injection][i] -= η[i] * qw[j]
        end
    end

    for (i, node) in nw[:node]
        var[:net_h2_nodal_edge_out_flow][i] = 0
        for j in nw[:outgoing_pipes][i]
            var[:net_h2_nodal_edge_out_flow][i] += γ_pipe[j] * f_pipe[j]
        end
        for j in nw[:outgoing_compressors][i]
            var[:net_h2_nodal_edge_out_flow][i] += γ_comp[j] * f_comp[j]
        end
        for j in nw[:incoming_pipes][i]
            var[:net_h2_nodal_edge_out_flow][i] -= γ_pipe[j] * f_pipe[j]
        end
        for j in nw[:incoming_compressors][i]
            var[:net_h2_nodal_edge_out_flow][i] -= γ_comp[j] * f_comp[j]
        end
    end

    for (i, node) in nw[:node]
        net_h2_injection = var[:net_h2_nodal_injection][i]
        net_h2_nodal_edge_out_flow = var[:net_h2_nodal_edge_out_flow][i]
        con[:nodal_h2_mass_flow_balance][i] =
            JuMP.@constraint(model, net_h2_nodal_edge_out_flow - net_h2_injection == 0)
    end

    return
end

"Constraint:Node NG mass flow balance"
function constraint_ng_mass_flow_balance!(model,nw,var,con)
    con[:nodal_ng_mass_flow_balance] = Dict()
    var[:net_ng_nodal_injection] = Dict()
    var[:net_ng_nodal_edge_out_flow] = Dict()

    qs = var[:qs]
    qw = var[:qw]
    f_pipe = var[:f_pipe]
    f_comp = var[:f_comp]
    η = var[:η]
    γ_pipe = var[:γ_pipe]
    γ_comp = var[:γ_comp]

    for (i,node) in nw[:node]
        var[:net_ng_nodal_injection][i] = 0
        for j in nw[:dispatchable_receipts_in_node][i]
            η_s = nw[:dispatchable_receipt][j]["injection_conc"]
            var[:net_ng_nodal_injection][i] += (1-η_s) * qs[j]
        end
        for j in nw[:dispatchable_deliveries_in_node][i]
            var[:net_ng_nodal_injection][i] -= (1-η[i]) * qw[j]
        end
    end

    for (i, node) in nw[:node]
        var[:net_ng_nodal_edge_out_flow][i] = 0
        for j in nw[:outgoing_pipes][i]
            var[:net_ng_nodal_edge_out_flow][i] += (1-γ_pipe[j]) * f_pipe[j]
        end
        for j in nw[:outgoing_compressors][i]
            var[:net_ng_nodal_edge_out_flow][i] += (1-γ_comp[j]) * f_comp[j]
        end
        for j in nw[:incoming_pipes][i]
            var[:net_ng_nodal_edge_out_flow][i] -= (1-γ_pipe[j]) * f_pipe[j]
        end
        for j in nw[:incoming_compressors][i]
            var[:net_ng_nodal_edge_out_flow][i] -= (1-γ_comp[j]) * f_comp[j]
        end
    end

    for (i, node) in nw[:node]
        net_ng_injection = var[:net_ng_nodal_injection][i]
        net_ng_nodal_edge_out_flow = var[:net_ng_nodal_edge_out_flow][i]
        con[:nodal_ng_mass_flow_balance][i] =
            JuMP.@constraint(model, net_ng_nodal_edge_out_flow - net_ng_injection == 0)
    end

    return
end

"Constraint:Slack Pressure"
function constraint_slack_pressure!(model,nw,var,con)
    nominal_pressure = nw[:nominal_pressure]
    con[:slack_pressure] = Dict()
    Π = var[:Π]
    for (i, node) in nw[:slack_nodes]
        con[:slack_pressure][i] = 
            JuMP.@constraint(model, Π[i] == node["nominal_pressure"]^2)
    end

    return
end

"Constraint:Node and Compressor concentration"
function constraint_node_compressor_conc!(model,nw,var,con)
    con[:node_compressor_conc] = Dict()

    γ_comp = var[:γ_comp]
    η = var[:η]

    for (i, compressor) in nw[:compressor]
        γ = γ_comp[i]
        η_fr = η[compressor["fr_node"]]
        con[:node_compressor_conc][i] = 
            JuMP.@NLconstraint(model, η_fr == γ)
    end

    return
end


"Constraint:Node and Edge concentration"

"Equation-based"
function constraint_node_pipe_conc_equation!(model,nw,var,con)
    con[:node_pipe_conc_eq] = Dict()
    
    f_pipe = var[:f_pipe]
    γ_pipe = var[:γ_pipe]
    η = var[:η]

    for (i, pipe) in nw[:pipe]
        f = f_pipe[i]
        γ = γ_pipe[i]
        η_fr = η[pipe["fr_node"]]
        η_to = η[pipe["to_node"]]
        
        con[:node_pipe_conc_eq][i] = 
            JuMP.@NLconstraint(model, η_fr == γ)
    end

    return
end


"Building constraints"
function build_constraints!(ss, model, var)

    con = Dict()

    nw = ss.ref;
    params = ss.params;

    ####Defining and adding the Constraints####

    constraint_energy_withdraw!(model, nw, var, con)
    # constraint_withdrawal_conc!(model,nw,var,con)
    constraint_pipe_pressure!(model, nw, var, con, params)
    constraint_compressor_pressure!(model, nw, var, con)
    # constraint_mass_flow_balance!(model, nw, var, con)
    constraint_h2_mass_flow_balance!(model, nw, var, con)
    constraint_ng_mass_flow_balance!(model, nw, var, con)
    constraint_slack_pressure!(model, nw, var, con)
    constraint_node_compressor_conc!(model, nw, var, con)
    constraint_node_pipe_conc_equation!(model, nw, var, con)

    return model, var, con

end
