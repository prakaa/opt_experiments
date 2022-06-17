struct Generator{T <: Float64}
    name::String
    min_gen::T
    max_gen::T
    ramp_up::T
    ramp_down::T
    srmc::T
end


"""
    Generator(name::String; min_gen::Float64=0.0, max_gen::Float64=0.0,
              ramp_up::Float64=9999.0, ramp_down::Float64=9999.0, srmc::Float64=0.0)

Creates a Generator

# Arguments
- `name::String`: Name of the generator. Must be unique.
- `min_gen::Float64`: Minimum generation in MW.
- `max_gen::Float64`: Maximum generation in MW.
- `ramp_up::Float64`: Ramp up rate in MW/min.
- `ramp_down::Float64`: Ramp down rate in MW/min.
- `srmc::Float64`: Ramp down rate in MW/min.

"""
function Generator(name::String; min_gen::Float64=0.0, max_gen::Float64=0.0,
                   ramp_up::Float64=9999.0, ramp_down::Float64=9999.0,
                   srmc::Float64=0.0)
    @assert(max_gen ≥ min_gen, "Maximum generation should be greater than minimum")
    @assert(min_gen ≥ 0.0, "Minimum generation should be greater than 0")
    @assert(ramp_up ≥ 0.0, "Ramp up should be greater than 0")
    @assert(ramp_down ≥ 0.0, "Ramp down should be greater than 0")
    @assert(srmc ≥ 0.0, "SRMC should be greater than 0")
    return Generator(name, min_gen, max_gen, ramp_up, ramp_down, srmc)
end
