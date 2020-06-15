using
    CSV,
    Optim,
    Turing,
    ArgParse,
    # DataFrames,
    Distributions

include("util.jl")
include("sird.jl")

# disable_logging(Logging.Warn)

function cliargs()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--draws"
        help = "Number of draws"
        arg_type = Int
        default = 1000

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

function learn(data, observe, n_samples, workers)
    @model f(x, ::Type{T} = Float64) where {T} = begin
        # priors
        theta = Vector{T}(undef, length(parameters))
        for (i, (a, b)) in enumerate(priors())
            theta[i] ~ NamedDist(b, a)
        end
        view = observe(theta)

        # likelihood priors
        # sigma = Vector{T}(undef, length(compartments))
        # for i in 1:length(sigma)
        #     sigma[i] ~ InverseGamma(2, 1)
        # end

        # likelihood
        for i in 1:length(view)
            for (j, y) enumerate(view(i - 1))
                x[i,j] ~ Poisson(y)
            end
        end
    end

    model = f(data)
    sampler = NUTS(convert(Int, n_samples * 0.25), 0.95)
    parallel_type = MCMCThreads()

    return sample(model, sampler, parallel_type, n_samples, workers;
                  drop_warmup=true)
end

function main(df, args)
    epimodel = EpiModel(df)
    observed = nrow(df) - 1
    ode = solver(df, epimodel, observed)

    data = convert.(Float64, Matrix(last(df, observed)))
    chains = learn(data, ode, args["draws"], args["workers"])
    if !isnothing(args["trace"])
        write(args["trace"], chains)
    end

    n = args["posterior"]
    if !isnothing(n) && 0 < n <= length(chains)
        chains = sample(chains, n)
    end

    return select(DataFrame(chains), parameters, copycols=false)
end

CSV.write(stdout, main(load(stdin, compartments), cliargs()))
