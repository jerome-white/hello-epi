using Distributions

include("epimodel.jl")

function build()
    compartments = (
        (:susceptible, false),
        (:infected,    true),
        (:recovered,   true),
        (:deceased,    true),
    )
    parameters = (
        (:beta,  Uniform(0.0, 10.0)),
        (:gamma, Uniform(0.0,  2.0)),
        (:mu,    Uniform(0.0,  1.0)),
    )

    return EpiModel(compartments, parameters)
end

function play(N::Int)
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
