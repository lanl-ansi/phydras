# phydras

The Pipeline Hydrogen Decarbonization and Repurposing Analyzers (P-HyDRAs) are a set of prototype computational tools for simulating and optimizing midstream natural gas pipeline system operations subject to location and time-dependent hydrogen blending. 

# Optimization Model

The optimization model can be run through phydras/run_file.ipynd, where the Jupyter Notebook calls on a collection of julia scripts that are imported from phydras/src. Mainly:

* `io/data_utils.jl` parses the input data network, boundary conditions, and parameters.
* `core/variables.jl` imports variables and upper and lower bounds associated with the variable for the optimization.
* `core/constraints.jl` contains the constraints of the optimization.
* `core/objective.jl` computes the components of the objective function and builds the objective function.
* `core/assemble.jl` is where the solver is defined and the optimizer is run.
* `core/output.jl` and `core/multipliers.jl` saves all the physical variables and multipliers into a dictionary.

A plotting script `plot_network.ipynb` is included for visualization of outputs of large networks.

Three existing example networks are included in the repository, and 8-node network and two 40-node networks, along with the parameters for the case scenarios presented in the paper. Their outputs are available under the `output` folder.

# Publications

Sodwatana, Mo, Saif R. Kazi, Kaarthik Sundar, and Anatoly Zlotnik. "Optimization of Hydrogen Blending in Natural Gas Networks for Carbon Emissions Reduction." In 2023 American Control Conference (ACC), pp. 1229-1236. IEEE, 2023.

# License

This software is provided under a BSD License for Open-Source Copyright O4683: Pipeline Hydrogen Decarbonization and Repurposing Analyzers. 
