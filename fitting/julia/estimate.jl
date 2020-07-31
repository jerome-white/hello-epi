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
    end

    return parse_args(s)
end

function learn(data, epimodel, observe, n_samples)
    @model f(x, ::Type{T} = Float64) where {T} = begin
        # priors
        theta = Vector{T}(undef, nparameters(epimodel))
        for (i, (a, b)) in enumerate(priors(epimodel))
            theta[i] ~ NamedDist(b, a)
        end

        obs = observe(theta)
        if isnothing(obs)
            Turing.acclogp!(_varinfo, -Inf)
            return
        end
        compartments = nobserved(epimodel)

        # likelihood priors
        sigma = Vector{T}(undef, compartments)
        for (i, j) in zip(1:compartments, [1, 2, 2])
            sigma[i] ~ InverseGamma(j, 1)
        end

        # likelihood
        for i in 1:compartments
            x[:,i] ~ MvNormal(view(obs, :, i), sqrt(sigma[i]))
        end
        # for i in 1:first(size(view))
        #     x[i,:] ~ MvNormal(view(obs, i, :), sqrt.(sigma))
        # end
    end

    model = f(data)
    n_adapts = round(Int, n_samples * 0.25)
    sampler = NUTS(n_adapts, 0.65;
                   max_depth=10)

    return sample(model, sampler, n_samples + n_adapts;
                  drop_warmup=true,
                  progress=false)
end

function main(args, fp)
    epimodel = build()
    df = load(read(fp), epimodel)
    ode = solver(epimodel, args["population"], df;
                 lead_time=args["lead"])
    data = Matrix{Float64}(df)
    chains = learn(data, epimodel, ode, args["draws"])
    write(args["trace"], chains)
end

main(cliargs(), stdin)
