using
    DataFrames,
    Distributions

compartments = [
    :infected,
    :recovered,
    :deceased,
]

parameters = [
    :beta,
    :gamma,
    :mu,
    :rho,
]

function EpiModel(N::Number)
    return function (du, u, p, t)
        (I, _, _) = u
        (beta, gamma, mu, rho) = p

        du[2] = gamma * I
        du[3] = mu * I
        du[1] = beta * I * rho / N - du[2] - du[3]
    end
end

function priors(df::DataFrame, N::Number)
    upper = N - maximum(sum.(eachrow(df)))
    dists = (
        Uniform(0.0, 10.0),
        Uniform(0.0, 5.0),
        Uniform(0.0, 2.0),
        truncated(Poisson(N), 1, upper),
    )

    Channel() do channel
        for i in zip(parameters, dists)
            put!(channel, i)
        end
    end
end
