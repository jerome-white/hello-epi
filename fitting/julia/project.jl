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
        help = "Data against which to project"

        "--forward"
        help = "Number of days to project into the future"
        arg_type = Int
    end

    return parse_args(s)
end

function main(df, args)
    reference = convert.(Float64, load(args["observations"]))

    idxcols = 2
    days = nrow(reference) + args["forward"]
    dimensions = (
        nrow(df) * days,
        ncol(reference) + idxcols, # compartment names plus "order" and "day"
    )
    buffer = SharedArray{Float64}(dimensions)

    @threads for i in 1:nrow(df)
        ode = solver(reference, days)
        sol = ode(convert(Vector, df[i,:]))

        tspan = size(sol, 3)
        order = repeat([i], tspan)
        index = range(0, stop=tspan-1)
        y = i * tspan
        x = y - tspan + 1

        buffer[x:y,1:idxcols] = hcat(order, index)
        for j in 1:size(sol, 2)
            col = j + idxcols
            buffer[x:y,col] = sol[j,:]
        end
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
