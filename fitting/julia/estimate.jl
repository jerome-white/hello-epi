using
    CSV,
    Optim,
    Turing,
    ArgParse,
    # DataFrames,
    Distributions

include("util.jl")

# disable_logging(Logging.Warn)

function cliargs()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--samples"
        help = "Number of samples"
        arg_type = Int
        default = 1000

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
        sigma = Vector{Float64}(undef, size(view, 2))
        for i in length(sigma)
            sigma ~ InverseGamma(2, 3)
        end

        # likelihood
        for i in 1:size(view, 1)
            x[i,:] ~ MvNormal(view[i,:], sqrt(sigma))
        end
    end

    return sample(f(data), NUTS(), MCMCThreads(), n_samples, workers;
                  drop_warmup=true)
end

function main(df, args)
    ode = solver(df)
    # data = convert(Matrix, last(df, nrow(df) - 1))
    data = convert(Matrix, df)

    chains = learn(data, ode, args["samples"], args["workers"])
    if !isnothing(args["trace"])
        write(args["trace"], chains)
    end

    return select(DataFrame(chains), [:beta, :gamma, :mu], copycols=false)
end

CSV.write(stdout, main(convert.(Float64, load(stdin)), cliargs()))
