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

        "--lead"
        help = "Lead time"
        arg_type = Int

        "--trajectories"
        help = ""
        arg_type = Int
        default = 1
    end

    return parse_args(s)
end

df = CSV.File(read(stdin)) |> DataFrame!
args = cliargs()

model = build()
buckets = nobserved(model)
data = EpiData(args["observations"], model, args["population"];
               past=args["lead"],
               future=args["forward"])

idxcols = [
    :run,
    :day,
]
n = length(idxcols)
left = n + 1

days = active(data)
dimensions = (
    nrow(df) * days,
    n + buckets,
)
buffer = SharedArray{Float64}(dimensions)
buffer[1:end] .= NaN

stop = args["offset"] + days - 1
index = range(args["offset"], stop=stop)

dep = StandardDEParams()
# dep = NoiseDEParams(args["trajectories"], 5, Inf)

@threads for i in 1:nrow(df)
    theta = Vector(view(df, i, :))
    sol = integrate(model, data, dep, theta)
    if !isnothing(sol)
        bottom = i * days
        top = bottom - days + 1

        order = repeat([i], days)
        buffer[top:bottom,1:n] = hcat(order, index)
        buffer[top:bottom,left:end] = sol
    end
end

projections = DataFrame(buffer)
filter!(isfinite ∘ sum, projections)
rename!(projections, vcat(idxcols, observed(model)))
CSV.write(stdout, projections)
