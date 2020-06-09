using
    Optim,
    Turing,
    # DataFrames,
    Distributions

include("util.jl")

# disable_logging(Logging.Warn)

function learn(data, observe)
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

    return sample(f(data), NUTS(0.65), 1000)
end

function main(fp)
    df = convert.(Float64, load(fp))
    ode = solver(df)
    # data = convert(Matrix, last(df, nrow(df) - 1))
    data = convert(Matrix, df)
    estimates = learn(data, ode)
    write("estimates.jls", estimates)
end

main(stdin)
