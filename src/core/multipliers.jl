
function update_multipliers_fields_in_ref(ss::SteadyOptimizer, var::Dict{Symbol,Any},con)
    ref = ss.ref
    multipliers = Dict{Symbol,Any}()

    multipliers[:χuNG] = Dict()
    multipliers[:χlNG] = Dict()
    multipliers[:χuH2] = Dict()
    multipliers[:χlH2] = Dict()
    multipliers[:χd] = Dict()
    multipliers[:χg] = Dict()
    multipliers[:λjNG] = Dict()
    multipliers[:λjH2] = Dict()
    multipliers[:λjT] = Dict()
    multipliers[:βl] = Dict()
    multipliers[:ωu] = Dict()
    multipliers[:ωl] = Dict()
    multipliers[:ωe] = Dict()
    multipliers[:μij] = Dict()
    multipliers[:θe] = Dict()
    multipliers[:θu] = Dict()
    multipliers[:θcu] = Dict()
    multipliers[:θcl] = Dict()
    multipliers[:ωce] = Dict()
    multipliers[:λd] = Dict()

    for i in SNG_NODES
        multipliers[:χuNG][i] = dual(UpperBoundRef(var[:qs][i]))/ss.nominal_values[:mass_flow] * -1
        multipliers[:χlNG][i] = dual(LowerBoundRef(var[:qs][i]))/ss.nominal_values[:mass_flow] * -1
    end

    for i in SH2_NODES
        multipliers[:χuH2][i] = dual(UpperBoundRef(var[:qs][i]))/ss.nominal_values[:mass_flow]
        multipliers[:χlH2][i] = dual(LowerBoundRef(var[:qs][i]))/ss.nominal_values[:mass_flow]
    end

    for i in WDW_NODES
        j = ref[:dispatchable_delivery][i]["node_id"]
        multipliers[:χd][i] = dual(LowerBoundRef(var[:qw][i]))/ss.nominal_values[:mass_flow]
        multipliers[:χg][i] = dual(con[:energy_withdrawal][i]) *-1
        λe = (dual(con[:nodal_ng_mass_flow_balance][j])/ss.nominal_values[:mass_flow]*-1*(1-JuMP.value(var[:η][j])) + dual(con[:nodal_h2_mass_flow_balance][j])/ss.nominal_values[:mass_flow]*-1*JuMP.value(var[:η][j])) / (141.8 * JuMP.value(var[:η][j]) + 44.2 * (1 - JuMP.value(var[:η][j])))
        if i == 4 || i == 26 || i == 23 || i == 17 
            multipliers[:λd][i] = λe - BIDPRICEX - multipliers[:χd][i] + multipliers[:χg][i]
        else
            multipliers[:λd][i] = λe - BIDPRICE - multipliers[:χd][i] + multipliers[:χg][i]
        end
    end

    for i in NODES
        multipliers[:λjNG][i] = dual(con[:nodal_ng_mass_flow_balance][i])/ss.nominal_values[:mass_flow] * -1
        multipliers[:λjH2][i] = dual(con[:nodal_h2_mass_flow_balance][i])/ss.nominal_values[:mass_flow] * -1
        multipliers[:λjT][i] = (dual(con[:nodal_ng_mass_flow_balance][i])/ss.nominal_values[:mass_flow]*-1*(1-JuMP.value(var[:η][i])) + dual(con[:nodal_h2_mass_flow_balance][i])/ss.nominal_values[:mass_flow]*-1*JuMP.value(var[:η][i])) / (141.8 * JuMP.value(var[:η][i]) + 44.2 * (1 - JuMP.value(var[:η][i])))
        multipliers[:βl][i] = dual(LowerBoundRef(var[:Π][i])) / (ss.nominal_values[:pressure]^2)
        multipliers[:ωu][i] = dual(UpperBoundRef(var[:η][i]))
        multipliers[:ωl][i] = dual(LowerBoundRef(var[:η][i]))
    end

    for i in COMPRESSORS
        multipliers[:θe][i] = dual(con[:compressor_boost][i]) / (ss.nominal_values[:pressure]^2)
        multipliers[:θu][i] = dual(con[:compressor_boost_max][i]) / (ss.nominal_values[:pressure]^2)
        multipliers[:θcu][i] = dual(UpperBoundRef(var[:ω][i]))
        multipliers[:θcl][i] = dual(LowerBoundRef(var[:ω][i]))
        multipliers[:ωce][i] = dual(con[:node_compressor_conc][i])
    end

    for i in EDGES
        dual_μ = dual(con[:pipe_physics][i])
        if dual_μ < 0 
            multipliers[:μij][i] = sqrt(dual_μ*-1) / (ss.nominal_values[:pressure]^2)
        else
            multipliers[:μij][i] = sqrt(dual_μ) /(ss.nominal_values[:pressure]^2)
        end
        multipliers[:ωe][i] = dual(con[:node_pipe_conc_eq][i])
    end

    return multipliers

end

