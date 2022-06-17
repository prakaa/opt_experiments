"""
    run_multiperiod(demand::SVector, t_horizon::Int64)

Initialises and solves a series of multi-period dispatch models/simulations. The **horizon**
of each model/simulation is defined by `t_horizon`, which must be a factor of
`length(demand)`.
"""
function run_multiperiod(demand::SVector, t_horizon::Int64)
    @assert(length(demand) % t_horizon == 0, "t_horizon must be a factor of demand")
    generator_ids = merge(create_portfolio_gen(), create_other_gens())
    (prices, generation) = (DataFrame(), DataFrame())
    for t_init in 1:t_horizon:length(demand)
        t_end = t_init + t_horizon - 1
        model = Model(Gurobi.Optimizer)
        model = initialise_multiperiod(model, t_init, t_end, demand, generator_ids)
        optimize!(model)
        if termination_status(model) == MOI.OPTIMAL && has_duals(model)
            dual_array = Array(dual.(model[:Balance]))
            gen_array = value.(model[:GENERATION].data)
            prices = vcat(prices, DataFrame(:intervals=>t_init:t_end,
                                            :prices=>dual_array))
            generation = vcat(generation, DataFrame(
                :generator=>repeat(model[:GENERATION].axes[1], t_horizon),
                :intervals=>repeat(t_init:t_end, inner=size(gen_array, 1)),
                :generation=>reshape(gen_array, length(gen_array))
                ))
        elseif !has_duals(model)
            println("Change solver to one that calculates duals")
        else
            println("Error in optimising model")
        end
    end
    return prices, generation
end
