# https://turing.ml/dev/tutorials/10-bayesiandiffeq/#including-process-noise-estimation-of-stochastic-differential-equations

using
    # Optim,
    Turing,
    ArgParse,
    Distributions

include("epidata.jl")
include("epimodel.jl")
include("diffequtils.jl")
include("modeler.jl") # virtual

# disable_logging(Logging.Warn)

function cliargs()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--draws"
        help = "Number of draws"
        arg_type = Int
        default = 1000

        "--trajectories"
        help = ""
        arg_type = Int
        default = 1

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

function learn(epidat::EpiData, epimod::EpiModel, n_samples::Int)
    @model f(x, ::Type{T} = Float64) where {T} = begin
        # priors
        theta = Vector{T}(undef, nparameters(epimod))
        for (i, (a, b)) in enumerate(priors(epimod))
            theta[i] ~ NamedDist(b, a)
        end

        compartments = nobserved(epimod)

        # likelihood priors
        sigma = Vector{T}(undef, compartments)
        for (i, (j, k)) in zip(1:compartments, ((3, 0.5), (2, 0.5), (2, 1)))
            sigma[i] ~ InverseGamma(j, k)
        end
        # for i in 1:compartments
        #     sigma[i] ~ InverseGamma(2, 0.5)
        # end

        # likelihood
        prob = mknoise(epidat, epimod, theta)
        solution = prob(DEParams(100, 6, 51))

        if isnothing(solution)
            Turing.acclogp!(_varinfo, -Inf)
        else
            sol = convert.(T, solution)
            for i in 1:compartments
                y = @view sol[:,i]
                x[:,i] ~ MvNormal(y, sqrt(sigma[i]))
            end
            # for i in 1:first(size(view))
            #     x[i,:] ~ MvNormal(view(sol, i, :), sqrt.(sigma))
            # end
        end
    end

    model = f(matrix(epidat))
    n_adapts = round(Int, n_samples * 0.25)
    sampler = NUTS(n_adapts, 0.45;
                   max_depth=6)

    return sample(model, sampler, n_samples + n_adapts;
                  drop_warmup=true,
                  progress=false)
end

function main(args, fp)
    epimod = build()
    epidat = EpiData(read(fp), epimod, args["population"];
                     lead_time=args["lead"])
    chains = learn(epidat, epimod, args["draws"])
    write(args["trace"], chains)
end

main(cliargs(), stdin)
