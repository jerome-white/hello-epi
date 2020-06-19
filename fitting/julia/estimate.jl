using
    CSV,
    Optim,
    Turing,
    ArgParse,
    # MCMCChains,
    Distributions

include("util.jl")
# include("sird.jl")
include("ird.jl")

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

        "--posterior"
        help = "Number of samples to take from the posterior"
        arg_type = Int
        default = nothing

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

function learn(data, observe, prior, n_samples, workers)
    @model f(x, ::Type{T} = Float64) where {T} = begin
        # priors
        theta = Vector{T}(undef, length(parameters))
        for (i, (a, b)) in enumerate(prior())
            theta[i] ~ NamedDist(b, a)
        end
        view = observe(theta)

        # likelihood priors
        sigma = Vector{T}(undef, length(compartments))
        for i in 1:length(sigma)
            sigma[i] ~ InverseGamma(2, 1)
        end

        # likelihood
        for i in 1:length(compartments)
            x[:,i] ~ MvNormal(view[i,:], sqrt(sigma[i]))
        end
    end

    model = f(data)
    sampler = NUTS(round(Int, n_samples * 0.25), 0.65)
    parallel_type = MCMCThreads()

    return sample(model, sampler, parallel_type, n_samples, workers;
                  drop_warmup=true)
end

function main(df, args)
    epimodel = EpiModel(args["population"])
    ode = solver(df, epimodel)

    data = Matrix{Float64}(df)
    prior = priors(df, args["population"])
    chains = learn(data, ode, prior, args["draws"], args["workers"])
    if !isnothing(args["trace"])
        write(args["trace"], chains)
    end

    results =  select(DataFrame(chains), parameters, copycols=false)

    n = args["posterior"]
    if !isnothing(n) && 0 < n <= nrow(results)
        rows = sample(1:nrow(results), n; replace=false)
        results = results[rows,:]
    end

    return results
end

CSV.write(stdout, main(load(stdin, compartments), cliargs()))
