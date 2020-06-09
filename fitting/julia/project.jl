using
    CSV,
    DataFrames,
    SharedArrays

include("util.jl")

df = CSV.read(stdin)
reference = load("raw.csv")

dimensions = (
    nrow(df) * 180,
    ncol(reference) + 2, # compartment names plus order and day
)
buffer = SharedArray{Float64}(dimensions)

@threads for (i, p) in enumerate(eachrow(df))
    ode = solver(reference)
    sol = ode(convert(Vector, p))
    tspan = size(sol, 1)
    estimates = hcat(repeat([i], tspan), range(0, stop=tspan-1), sol)

    y = i * tspan
    x = y - tspan + 1
    buffer[x:y,:] = estimates
end

projections = DataFrame(buffer)
rename!(projections, [:susceptible, :infected, :deceased, :recovered])
CSV.write(stdout, projections)
