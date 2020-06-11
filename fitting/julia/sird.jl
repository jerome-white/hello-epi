using
    DataFrames

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
