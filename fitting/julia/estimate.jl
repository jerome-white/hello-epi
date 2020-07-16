using
    Optim,
    Turing,
    ArgParse,
    Distributions

include("util.jl")
include("modeler.jl")

# disable_logging(Logging.Warn)

function cliargs()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--draws"
        help = "Number of draws"
        arg_type = Int
        default = 1000

        "--population"
        help = "Population"
        arg_type = Int

        "--lead"
        help = "Population"
        arg_type = Int

        "--trace"
        help = "File to dump Turing trace information"
        default = nothing

        "--workers"
        help = "Number of parallel workers for sampling"
        arg_type = Int
        default = length(Sys.cpu_info())
    end

    return parse_args(s)
end

function learn(data, epimodel, observe, n_samples, workers)
    @model f(x, ::Type{T} = Float64) where {T} = begin
        # priors
        theta = Vector{T}(undef, nparameters(epimodel))
        for (i, (a, b)) in enumerate(priors(epimodel))
            theta[i] ~ NamedDist(b, a)
        end

        view = observe(theta)
        if isnothing(view)
            Turing.acclogp!(_varinfo, -Inf)
            return
        end
        compartments = nobserved(epimodel)

        # likelihood priors
        sigma = Vector{T}(undef, compartments)
        for i in 1:length(sigma)
            sigma[i] ~ InverseGamma(2, 1)
        end

        # likelihood
        for i in 1:compartments
            x[:,i] ~ MvNormal(view[:,i], sqrt(sigma[i]))
        end
        # for i in 1:length(view)
        #     x[:,i] ~ MvNormal(view[i,:], sqrt.(sigma))
        # end
    end

    model = f(data)
    sampler = NUTS(round(Int, n_samples * 0.25), 0.65;
                   max_depth=10)
    parallel_type = MCMCThreads()

    return sample(model, sampler, parallel_type, n_samples, workers;
                  drop_warmup=true)
end

function main(args, fp)
    epimodel = build()
    df = load(read(fp), epimodel)
    ode = solver(epimodel, args["population"], df;
                 lead_time=args["lead"])
    data = Matrix{Float64}(df)
    chains = learn(data, epimodel, ode, args["draws"], args["workers"])
    write(args["trace"], chains)
end

main(cliargs(), stdin)
