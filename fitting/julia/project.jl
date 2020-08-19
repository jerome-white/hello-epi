using
    CSV,
    ArgParse,
    Statistics,
    DataFrames,
    SharedArrays,
    Base.Threads

include("epidata.jl")
include("epimodel.jl")
include("diffequtils.jl")
include("modeler.jl") # virtual

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

        "--population"
        help = "Population"
        arg_type = Int

        "--resample"
        help = ""
        arg_type = Int
        default = 1

        "--lead"
        help = "Lead time"
        arg_type = Int
    end

    return parse_args(s)
end

function main(df, args)
    model = build()
    compartments = nobserved(model)
    data = EpiData(args["observations"], model, args["population"];
                   lead_time=args["lead"])

    idxcols = [
        :run,
        :day,
    ]
    n = length(idxcols)
    left = n + 1

    days = nrow(reference) + args["forward"]
    dimensions = (
        nrow(df) * days,
        n + compartments,
    )
    buffer = SharedArray{Float64}(dimensions)
    buffer[1:end] .= NaN

    stop = args["offset"] + days - 1
    index = range(args["offset"], stop=stop)

    @threads for i in 1:nrow(df)
        theta = @view df[i,:]
        prob = mknoise(data, model, theta)
        sol = prob(DEParams(10, 6))

        bottom = i * days
        top = bottom - days + 1

        order = repeat([i], days)
        buffer[top:bottom,1:n] = hcat(order, index)
        buffer[top:bottom,left:end] = sol
    end

    projections = DataFrame(buffer)
    filter!(isfinite ∘ sum, projections)
    rename!(projections, vcat(idxcols, observed(model)))

    return projections
end

CSV.write(stdout, main(DataFrame!(CSV.File(read(stdin))), cliargs()))
