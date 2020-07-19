using
    DataFrames,
    Distributions

compartments = [
    :infected,
    :recovered,
    :deceased,
]

parameters = [
    :r0,
    :gamma,
    :mu,
    :rho,
]

function EpiModel(N::Number)
    return function (du, u, p, t)
        (I, _, _) = u
        (r0, gamma, mu, rho) = p
        (gamma, mu) = ./(1, [gamma, mu])

        S = N * rho - sum(u)
        beta = r0 * gamma

        du[2] = I * gamma
        du[3] = I * mu
        du[1] = I * beta * S / N - du[2] - du[3]
    end
end

function priors()
    dists = (
        truncated(Normal(1, 1), 0, Inf),
        truncated(Erlang(3, 14 / 3), 1, Inf),
        truncated(Erlang(2, 20 / 2), 1, Inf),
        Uniform(0.0, 1.0),
    )

    Channel() do channel
        for i in zip(parameters, dists)
            put!(channel, i)
        end
    end
end
