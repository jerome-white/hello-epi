using Distributions

include("epimodel.jl")

function build()
    compartments = (
        (:susceptible, false),
        (:exposed,     false),
        (:infected,    true),
        (:recovered,   true),
        (:deceased,    true),
    )
    parameters = (
        (:beta,  Uniform(0.0, 10.0)),
        (:alpha, Uniform(0.0,  5.0)),
        (:gamma, Uniform(0.0,  2.0)),
        (:mu,    Uniform(0.0,  1.0)),
    )

    return EpiModel(compartments, parameters)
end

function play(N::Int)
    return function (du, u, p, t)
        (S, E, I, _, _) = u
        (beta, alpha, gamma, mu) = p

        dS = beta * S * I / N
        dE = alpha * E

        du[4] = gamma * I
        du[5] = mu * I

        du[1] = -dS
        du[2] =  dS - dE
        du[3] =  dE - du[4] - du[5]
    end
end
