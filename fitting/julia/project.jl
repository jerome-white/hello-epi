using
    CSV,
    ArgParse,
    DataFrames,
    SharedArrays,
    Base.Threads

include("util.jl")

function cliargs()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--observations"
        help = ""

        "--duration"
        help = ""
        arg_type = Int
    end

    return parse_args(s)
end

function main(df, args)
    reference = convert.(Float64, load(args["observations"]))

    dimensions = (
        nrow(df) * args["duration"],
        ncol(reference) + 2, # compartment names plus "order" and "day"
    )
    buffer = SharedArray{Float64}(dimensions)

    @threads for i in 1:nrow(df)
        ode = solver(reference, args["duration"])
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

    return projections
end

CSV.write(stdout, main(CSV.read(stdin), cliargs()))
