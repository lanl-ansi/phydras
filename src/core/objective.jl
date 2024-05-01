
function load_shed!(model,nw,var)
    BIDPRICE
    load_shed_expressions = []

    qs = var[:qs]
    qw = var[:qw]
    η = var[:η]

    for (i, receipt) in nw[:dispatchable_receipt]
        push!(
            load_shed_expressions,
            JuMP.@expression(model, -receipt["offer_price_H2"] * qs[i] * receipt["injection_conc"] - 
            receipt["offer_price_NG"] * qs[i] * (1 - receipt["injection_conc"]))
        )
    end
    for (i, delivery) in nw[:dispatchable_delivery]
        if i == 4 || i == 26 || i == 23 || i == 17             # nodeids 12, 37, 17, 16
            push!(
                load_shed_expressions,
                JuMP.@expression(model, BIDPRICEX * qw[i] * (141.8 * η[delivery["node_id"]] + 
                44.2 * (1 - η[delivery["node_id"]])))
            )
        else
            push!(
                load_shed_expressions,
                JuMP.@expression(model, BIDPRICE * qw[i] * (141.8 * η[delivery["node_id"]] + 
                44.2 * (1 - η[delivery["node_id"]])))
            )
        end
    end
    for (i, delivery) in nw[:dispatchable_delivery]
        push!(
            load_shed_expressions,
            JuMP.@expression(model, CARBON_OFFSET * qw[i] * η[delivery["node_id"]] * 141.8/44.2 * 44/16)
        )
    end

    return load_shed_expressions
end

function compressor_cost!(model,nw,var)

    compressor_cost_expression= []
    
    Π = var[:Π]
    γ_comp = var[:γ_comp]
    f_comp = var[:f_comp]
    ω = var[:ω]
    T = 288.706
    η = 0.13/3600 # $ per kw-s

    for (i,compressor) in nw[:compressor]
        Π_to = Π[compressor["to_node"]]
        Π_fr = Π[compressor["fr_node"]]
        ω_comp = ω[i]
        # κ = 1.405 * γ_comp[i] + 1.303 * (1 - γ_comp[i])
        # G = 0.0696 * γ_comp[i] + 0.6 * (1 - γ_comp[i])
        κ = 1.308
        G = 0.574

        push!(
            compressor_cost_expression,
            JuMP.@NLexpression(model, η * (T * 286.76 * κ) / (G * (κ-1)) * ((sqrt(ω_comp))^((κ - 1) / κ) - 1) * abs(f_comp[i]))
        )
    end

    return compressor_cost_expression
end

function build_objective!(ss, model, var)
    
    nw = ss.ref;

    load_shed_expressions = load_shed!(model, nw, var)

    compressor_cost_expressions = compressor_cost!(model, nw, var)

    nominal_massflow = nw[:nominal_massflow]

    JuMP.@NLobjective(
            model,
            Max,
            sum(load_shed_expressions[i] for i = 1:length(load_shed_expressions)) * nominal_massflow -
            sum(compressor_cost_expressions[i] for i = 1:length(compressor_cost_expressions)) * nominal_massflow 
        )

    return model

end