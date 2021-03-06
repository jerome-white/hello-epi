using
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

function learn(epidat::EpiData,
               epimod::EpiModel,
               dep::AbstractDEParams,
               n_samples::Int)
    @model f(x, ::Type{T} = Float64) where {T} = begin
        # priors
        theta = Vector{T}(undef, nparameters(epimod))
        for (i, (a, b)) in enumerate(priors(epimod))
            theta[i] ~ NamedDist(b, a)
        end

        # likelihood priors
        phi  = Vector{T}(undef, nobserved(epimod))
        phi .~ positive(Beta(2, 5); lower=1e-12)
        # phi .~ positive(Normal(0, 5); lower=1e-6)

        # likelihood
        observed = integrate(epimod, epidat, dep, theta)
        if isnothing(observed)
            Turing.acclogp!(_varinfo, -Inf)
        else
            for (i, (mu, sigma)) in enumerate(zip(eachcol(observed), phi))
                x[:,i] ~ MvNegativeBinomial(mu, sigma)
            end
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

args = cliargs()
epimod = build()
epidat = EpiData(read(stdin), epimod, args["population"];
                 past=args["lead"])
dep = StandardDEParams()
# dep = NoiseDEParams(args["trajectories"], 5)
chains = learn(epidat, epimod, dep, args["draws"])
write(args["trace"], chains)
