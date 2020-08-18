using
    CSV,
    ArgParse,
    Statistics,
    DataFrames,
    SharedArrays,
    Base.Threads

include("util.jl")
include("modeler.jl")

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

function estimate(ode, p, observations)
    (_, _, iterations) = size(observations)

    let i = 1
        while i <= iterations
            sol = ode(p)
            if isnothing(sol)
                @warn "Unable to find ODE solution"
                continue
            end
            observations[:,:,i] = sol
            i += 1
        end
    end

    return mean(observations, dims=3)
end

function sampler(days::Int, compartments::Int, iterations::Int)
    observations = zeros(Float64, days, compartments, iterations)

    return function (ode, parameters)
        p = convert(Vector, parameters)
        return estimate(ode, p, observations)
    end
end

function main(df, args)
    model = build()
    compartments = nobserved(model)
    reference = load(args["observations"], model)

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

    pick = sampler(days, compartments, args["resample"])

    @threads for i in 1:nrow(df)
        ode = solver(model, args["population"], days;
                     lead_time=args["lead"],
                     dt_order=6)
        sol = pick(ode, view(df, i, :))

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
