using
    CSV,
    ArgParse,
    DataFrames,
    SharedArrays,
    Base.Threads

include("util.jl")
include("sird.jl")

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
    reference = convert.(Float64, load(args["observations"], compartments))

    idxcols = [
        :run,
        :day,
    ]
    n = length(idxcols)

    days = nrow(reference) + args["forward"]
    dimensions = (
        nrow(df) * days,
        ncol(reference) + n,
    )
    buffer = SharedArray{Float64}(dimensions)

    @threads for i in 1:nrow(df)
        epimodel = EpiModel(reference)
        ode = solver(reference, epimodel, days)
        sol = ode(convert(Vector, df[i,:]))

        tspan = size(sol, 3)
        order = repeat([i], tspan)
        index = range(0, stop=tspan-1)
        y = i * tspan
        x = y - tspan + 1

        buffer[x:y,1:n] = hcat(order, index)
        for j in 1:size(sol, 2)
            col = j + n
            buffer[x:y,col] = sol[j,:]
        end
    end

    projections = DataFrame(buffer)
    rename!(projections, vcat(idxcols, compartments))

    return projections
end

CSV.write(stdout, main(CSV.read(stdin), cliargs()))
