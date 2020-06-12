using
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

function EpiModel()
    return function (du, u, p, t)
        (I, _, _) = u
        (beta, gamma, mu, rho) = p

        du[2] = gamma * I
        du[3] = mu * I
        du[1] = beta * I * rho - du[2] - du[3]
    end
end

function priors()
    dists = (
        Uniform(0.0, 10.0),
        Uniform(0.0, 2.0),
        Uniform(0.0, 1.0),
        Uniform(0.0, 0.2),
    )

    Channel() do channel
        for i in zip(parameters, dists)
            put!(channel, i)
        end
    end
end