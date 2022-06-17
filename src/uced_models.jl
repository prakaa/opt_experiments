"""
    initialise_multiperiod(model::Model, t_init::Int64, t_end::Int64, demand::SVector,
                           generator_ids::Dict{Symbol, Generator{Float64}};
						   generator_ini_conds::Dict{Symbol, Float64}=Dict{Symbol, Float64}())

Creates a multi-period dispatch model for all (5-minute) dispatch intervals from `t_init` to `t_end`. Forward-looking ramping constraints apply from `t` to `t_end`.
If `t_init > 1` (i.e. `t_init` is not the first interval), the function expects initial conditions (i.e. MW generation) provided in
`generator_ini_conds` so that a ramp constraint between `t_init-1` and `t_init` can be added to the model (i.e. backward-looking ramp constraint).
"""
function initialise_multiperiod(model::Model, t_init::Int64, t_end::Int64,
								demand::SVector,
                                generator_ids::Dict{Symbol, Generator{Float64}};
								generator_ini_conds::Dict{Symbol, Float64}=Dict{Symbol, Float64}())
    @assert(t_init ≤ t_end, "End time must be ≥ start time")
    @variable(model,
              generator_ids[i].min_gen
              <= GENERATION[i=keys(generator_ids), t=t_init:t_end]
              <= generator_ids[i].max_gen)
    @variable(model, UNSERVED[t=t_init:t_end] ≥ 0.0)
	# Ramp constraints (backwards and forward looking)
    ## convert MW/min to MW by multiplying by 5 (minutes)
	if t_init > 1
		@constraint(model, BwdRampUp[i=keys(generator_ids), t=t_init],
		                             GENERATION[i, t] - generator_ini_conds[i]
		                             ≤ generator_ids[i].ramp_up * 5.0)
	    @constraint(model, BwdRampDown[i=keys(generator_ids), t=t_init],
	                                   GENERATION[i, t] - generator_ini_conds[i]
	                                   ≥ -generator_ids[i].ramp_down * 5.0)
	end
    @constraint(model, FwdRampUp[i=keys(generator_ids), t=t_init:t_end-1],
                                 GENERATION[i, t+1] - GENERATION[i, t]
                                 ≤ generator_ids[i].ramp_up * 5.0)
    @constraint(model, FwdRampDown[i=keys(generator_ids), t=t_init:t_end-1],
                                   GENERATION[i, t+1] - GENERATION[i, t]
                                   ≥ -generator_ids[i].ramp_down * 5.0)
	# Balance constraint
    @constraint(model, Balance[t=t_init:t_end],
                               sum(GENERATION[i, t] for i in keys(generator_ids))
                               + UNSERVED[t]  == demand[t])
	# Objective function with unserved
    @objective(model, Min, sum(generator_ids[i].srmc * GENERATION[i, t]
                               for i=keys(generator_ids), t=t_init:t_end)
                           + sum(15000.0 * UNSERVED[t] for t=t_init:t_end))
    return model
end


"""
    initialise_bilevel(model::BilevelModel, t_init::Int64, t_end::Int64,
                       demand::SVector,
                       portfolio_gens::Dict{Symbol, Generator{Float64}},
                       other_gens::Dict{Symbol, Generator{Float64}};
                       generator_ini_conds::Dict{Symbol, Float64}=Dict{Symbol, Float64}())

Creates a multi-period bilevel dispatch model for all (5-minute) dispatch intervals from
`t_init` to `t_end`.

## Bilevel
Upper level program optimises for offer price, given the capacity, SRMC and contracted
proportion of generation in portfolio_gens. Lower level program is dispatch/market clearing.

## Multi-period dispatch and ramping
Forward-looking ramping constraints apply from `t` to `t_end`.
If `t_init > 1` (i.e. `t_init` is not the first interval), the function expects initial
conditions (i.e. MW generation) provided in `generator_ini_conds` so that a ramp constraint
between `t_init-1` and `t_init` can be added to the model
(i.e. backward-looking ramp constraint).
"""
function initialise_bilevel(model::BilevelModel, t_init::Int64, t_end::Int64,
                            demand::SVector,
                            portfolio_gens::Dict{Symbol, Generator{Float64}},
                            other_gens::Dict{Symbol, Generator{Float64}};
                            generator_ini_conds::Dict{Symbol, Float64}=Dict{Symbol, Float64}())
    @assert(t_init ≤ t_end, "End time must be ≥ start time")
    generator_ids = merge(portfolio_gens, other_gens)
    # lower model
    ## power and unserved energy
    @variable(Lower(model),
              generator_ids[i].min_gen
              <= GENERATION[i=keys(generator_ids), t=t_init:t_end]
              <= generator_ids[i].max_gen)
    @variable(Lower(model), UNSERVED[t=t_init:t_end] ≥ 0.0)
    ## ramping constraints
	if t_init > 1
		@constraint(Lower(model), BwdRampUp[i=keys(generator_ids), t=t_init],
                                  GENERATION[i, t] - generator_ini_conds[i]
                                  ≤ generator_ids[i].ramp_up * 5.0)
	    @constraint(Lower(model), BwdRampDown[i=keys(generator_ids), t=t_init],
	                              GENERATION[i, t] - generator_ini_conds[i]
	                              ≥ -generator_ids[i].ramp_down * 5.0)
	end
    @constraint(Lower(model), FwdRampUp[i=keys(generator_ids), t=t_init:t_end-1],
                              GENERATION[i, t+1] - GENERATION[i, t]
                              ≤ generator_ids[i].ramp_up * 5.0)
    @constraint(Lower(model), FwdRampDown[i=keys(generator_ids), t=t_init:t_end-1],
                              GENERATION[i, t+1] - GENERATION[i, t]
                              ≥ -generator_ids[i].ramp_down * 5.0)
    ## balance
    @constraint(Lower(model), Balance[t=t_init:t_end],
                              sum(GENERATION[i, t] for i in keys(generator_ids))
                              + UNSERVED[t]  == demand[t])
    # upper model
    @variable(Upper(model), λ[t=t_init:t_end], DualOf(DualOf(Balance[t])))
    @variable(Upper(model), )
    return model
end
function solve_bilevel_sos()
    model = BilevelModel(Gurobi.Optimizer, mode = BilevelJuMP.SOS1Mode())

    @variable(Lower(model), x)
    @variable(Upper(model), y)

    @objective(Upper(model), Min, 3x +y)
    @constraints(Upper(model), begin
        x <= 5
        y <= 8
        y >= 0
    end)

    @objective(Lower(model), Min, -x)
    @constraints(Lower(model), begin
        x + y <= 8
        4x + y >= 8
        2x + y <= 13
        2x - 7y <= 0
    end)

    optimize!(model)
    return model
end
