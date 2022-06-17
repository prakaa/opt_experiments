using BilevelJuMP
using DataFrames
using Gurobi
using JuMP
using opt_experiments
using StaticArrays
using VegaLite


"""
    create_portfolio_gen()

Creates portfolio generators. Returns a `Dict` with each generator mapped to
its name as a Symbol.
"""
function create_portfolio_gen()

    peaker = Generator("Peaker", min_gen=10.0, max_gen=300.0, ramp_up=60.0, ramp_down=100.0,
                       srmc=300.0)
    generators_ids = Dict(Symbol(gen.name) => gen for (i, gen)
                          in enumerate((peaker,)))
    return generators_ids
end


"""
    create_other_gens()

Creates other generators. Returns a `Dict` with each generator mapped to
its name as a Symbol.
"""
function create_other_gens()
    coal = Generator("Coal", min_gen=100.0, max_gen=2000.0, ramp_up=30.0, ramp_down=100.0,
                     srmc=40.0)
    ccgt = Generator("CCGT", min_gen=100.0, max_gen=275.0, ramp_up=40.0, ramp_down=80.0,
                     srmc=150.0)
    wind = Generator("Wind", min_gen=0.0, max_gen=300.0, ramp_up=9999.0,
                     ramp_down=9999.0, srmc=0.0)
    generators_ids = Dict(Symbol(gen.name) => gen for (i, gen)
                          in enumerate((coal, wind, ccgt)))
    return generators_ids
end



const demand = @SVector[880.0, 900.0, 1000.0, 1150.0, 1500.0,
                        2000.0, 1000.0, 800.0, 900.0, 1000.0]
demanddata = DataFrame(:intervals => 1:10, :demand => demand)

(prices_10, generation_10) = run_multiperiod(demand, 10)

generation_10 |>
@vlplot(x="intervals:n", width=600, height=300) +
@vlplot(
	mark={:area},
	y={:generation, title="Generation (MW)"},
	color={:generator, legend={title="Generator Type"}},
	title="10-period dispatch"
) +
(
	demanddata |>
	@vlplot(
		mark={:line, color=:black, strokeDash=2},
		x="intervals:n", y=:demand
	)
)
