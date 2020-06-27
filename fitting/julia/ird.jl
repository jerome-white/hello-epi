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
        (I, R, D) = u
        (beta, gamma, mu, rho) = p

        S = max(0, N * rho - (I + R + D))

        du[2] = I * gamma
        du[3] = I * mu
        du[1] = I * beta * S / N - du[2] - du[3]
    end
end

function priors()
    dists = (
        # truncated(Exponential(1 / 10), 0, 20),
        # truncated(Exponential(1 / 14), 0, 20),
        # truncated(Exponential(1 / 600), 0, 1),
        Uniform(0.0, 10.0),
        Uniform(0.0, 5.0),
        Uniform(0.0, 2.0),
        Uniform(0.0, 1.0),
    )

    Channel() do channel
        for i in zip(parameters, dists)
            put!(channel, i)
        end
    end
end
