"Builds the JuMP model"

function build_gas_model(ss::SteadyOptimizer, model_type)

    gas_model = JuMP.Model()

    gas_model, gas_variables = build_variables!(ss, gas_model)

    if model_type == "nlp_eq"
        gas_model, gas_variables, gas_constraints = build_constraints!(ss, gas_model, gas_variables)
    elseif model_type == "milp"
        gas_model, gas_variables, gas_constraints, auxiliary_variables, auxiliary_constraints = build_milp_formulation_mixed_gas!(ss, gas_model, gas_variables)
    else
        println("Error:undefined model_type")
    end

    gas_model = build_objective!(ss, gas_model, gas_variables)

    return gas_model, gas_variables, gas_constraints
end

struct SSReport
    model
    status
    var
    con
    sol
end

struct ShadowPrice
    λh2
    λng
    λtot
end

function run_optimizer(ss::SteadyOptimizer, model_type, solver_options::Dict{Any,Any})
   
    model, var, con = build_gas_model(ss, model_type)

    ipopt_solver = JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol" => 1e-05) #, "linear_solver" => "ma57")

    if model_type == "nlp_eq"
        JuMP.set_optimizer(model, ipopt_solver)
    elseif model_type == "milp"
        JuMP.set_optimizer(model, Gurobi.Optimizer)
    else
        println("Error:undefined model_type")
    end

    for i in keys(solver_options)
        JuMP.set_optimizer_attribute(model, i, solver_options[i])
    end

    JuMP.optimize!(model)
    status = termination_status(model)

    sol = update_solution_fields_in_ref(ss, var);
    
    multipliers = update_multipliers_fields_in_ref(ss,var,con);

    

    return SSReport(model, status, var, con, sol), multipliers

end
