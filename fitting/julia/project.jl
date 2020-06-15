using
    CSV,
    ArgParse,
    DataFrames,
    SharedArrays,
    Base.Threads

include("util.jl")
# include("sird.jl")
include("ird.jl")

function cliargs()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--observations"
        help = "Data against which to project"

        "--offset"
        help = ""
        arg_type = Int
        default = 0

        "--forward"
        help = "Number of days to project into the future"
        arg_type = Int
    end

    return parse_args(s)
end

function main(df, args)
    reference = load(args["observations"], compartments)

    idxcols = [
        :run,
        :day,
    ]
    n = length(idxcols)

    days = nrow(reference) + args["forward"]
    dimensions = (
        nrow(df) * days,
        n + length(compartments),
    )
    buffer = SharedArray{Float64}(dimensions)

    stop = args["offset"] + days - 1
    index = range(args["offset"], stop=stop)

    @threads for i in 1:nrow(df)
        epimodel = EpiModel()
        ode = solver(reference, epimodel, days)
        sol = ode(convert(Vector, df[i,:]))

        bottom = i * days
        top = bottom - days + 1

        order = repeat([i], days)
        buffer[top:bottom,1:n] = hcat(order, index)

        left = n + 1
        right = left + length(compartments) - 1
        for j in 1:days
            buffer[top,left:right] = sol(j - 1)
            top += 1
        end
    end

    projections = DataFrame(buffer)
    rename!(projections, vcat(idxcols, compartments))

    return projections
end

CSV.write(stdout, main(CSV.read(stdin), cliargs()))
