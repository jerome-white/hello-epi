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
        arg_type = Float64
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
        beta ~ Uniform(0.0, 1.0)
        gamma ~ Uniform(0.0, 1.0)
        mu ~ Uniform(0.0, 1.0)
        view = observe([beta, gamma, mu])

        # likelihood priors
        sigma = Vector{T}(undef, length(compartments))
        for i in 1:length(sigma)
            sigma[i] ~ InverseGamma(2, 1)
        end

        # likelihood
        for i in 1:size(view, 2)
            x[i,:] ~ MvNormal(vec(view[:,i]), sqrt.(sigma))
        end
    end

    return sample(f(data), NUTS(), MCMCThreads(), n_samples, workers;
                  drop_warmup=true)
end

function main(df, args)
    epimodel = EpiModel(df)
    observed = nrow(df) - 1
    ode = solver(df, epimodel, observed)
    data = convert(Matrix, last(df, observed))

    chains = learn(data, ode, args["draws"], args["workers"])
    if !isnothing(args["trace"])
        write(args["trace"], chains)
    end

    frac = args["posterior"]
    if !isnothing(frac) && 0 < frac < 1
        chains = sample(chains, convert(Int, length(chains) * frac))
    end

    return select(DataFrame(chains), parameters, copycols=false)
end

CSV.write(stdout, main(convert.(Float64,load(stdin, compartments)), cliargs()))
