using
    CSV,
    # Optim,
    Turing,
    DataFrames,
    Distributions,
    DifferentialEquations

# disable_logging(Logging.Warn)

function sird(N)
    return function (u, p, t)
        (S, I, _, _) = u
        (beta, gamma, mu) = p

        du = Array{Float64}(undef, size(u))
        dS = beta * I * S / N

        du[1] = -dS
        du[3] = gamma * I
        du[4] = mu * I
        du[2] = dS - du[3] - du[4]

        return du
    end
end

function load(fp)
    compartments = [
        :susceptible,
        :infected,
        :deceased,
        :recovered,
    ]

    return select(sort(CSV.read(fp), [:date]), compartments, copycols=false)
end

function solver(df)
    steps = nrow(df)

    ode = sird(maximum(sum.(eachrow(df))))
    u0 = convert(Array, first(df, 1))
    tspan = (0.0, convert(Float64, steps))
    prob = ODEProblem(ode, u0, tspan)

    saveat = collect(range(1, stop=steps, length=steps))

    return function (p)
        return solve(prob, Tsit5(); saveat=saveat, p=p)
    end
end

function infer(ode, data)
    @model function f(x, ::Type{T} = Float64) where {T <: Real}
        # priors
        beta ~ Uniform(0.0, 1.0)
        gamma ~ Uniform(0.0, 1.0)
        mu ~ Uniform(0.0, 1.0)

        sol = ode((beta, gamma, mu))
        if sol.retcode != :Success
            ErrorException(sol.retcode)
        end

        # likelihood priors
        sigma = Vector{Float64}(undef, ncols(Y))
        for i in length(sigma)
            sigma ~ InverseGamma(2, 3)
        end

        # likelihood
        for i in eachindex(sol)
            x[i,:] ~ MvNormal(sol[:,i], sqrt(sigma))
        end
    end

    return sample(f(data), NUTS())
end

function main(fp)
    df = convert.(Float64, load(fp))
    ode = solver(df)
    data = last(df, nrow(df) - 1)
    posterior = infer(ode, data)

    CSV.write("posterior.csv", posterior)
end

main(stdin)
