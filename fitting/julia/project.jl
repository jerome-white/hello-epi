using
    CSV,
    DataFrames,
    SharedArrays,
    Base.Threads

include("util.jl")

df = CSV.read(stdin)
reference = convert.(Float64, load("raw.csv"))

duration = 180
dimensions = (
    nrow(df) * duration,
    ncol(reference) + 2, # compartment names plus order and day
)
buffer = SharedArray{Float64}(dimensions)

@threads for i in 1:nrow(df)
    ode = solver(reference, duration)
    sol = ode(convert(Vector, df[i,:]))
    tspan = size(sol, 1)
    estimates = hcat(repeat([i], tspan), range(0, stop=tspan-1), sol)

    y = i * tspan
    x = y - tspan + 1
    buffer[x:y,:] = estimates
end

projections = DataFrame(buffer)
rename!(projections, [
    :run,
    :day,
    :susceptible,
    :infected,
    :recovered,
    :deceased,
])
CSV.write(stdout, projections)
