using
    DataFrames,
    Distributions

compartments = [
    :susceptible,
    :infected,
    :recovered,
    :deceased,
]

parameters = [
    :beta,
    :gamma,
    :mu,
]

function EpiModel(N::Number)
    return function (du, u, p, t)
        (S, I, _, _) = u
        (beta, gamma, mu) = p

        dS = beta * I * S / N

        du[1] = -dS
        du[3] = gamma * I
        du[4] = mu * I
        du[2] = dS - du[3] - du[4]
    end
end

function EpiModel(df::DataFrame)
    return EpiModel(maximum(sum.(eachrow(df))))
end

function priors()
    dists = (
        Uniform(0.0, 10.0),
        Uniform(0.0, 2.0),
        Uniform(0.0, 1.0),
    )

    Channel() do channel
        for i in zip(parameters, dists)
            put!(channel, i)
        end
    end
end
