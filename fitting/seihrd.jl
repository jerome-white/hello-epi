include("epimodel.jl")
include("distutils.jl")

function build()
    compartments = (
        (:susceptible,  false),
        (:exposed,      false),
        (:infected,     true),
        (:hospitalised, false),
        (:recovered,    true),
        (:deceased,     true),
    )

    parameters = (
        (:contacts,     GammaMeanStd(40, 20)),
        (:transmission, Beta(2, 5)),
        (:fatality,     Beta(0.25, 4)),
        (:incubation,   GammaMeanVariance(5.5, 6.5)),
        (:infectious,   positive(CauchyIQR(IQR(5.7, 8.5)))),
        (:recovery,     GammaMeanVariance(9.1, 14.7)),
    )

    return EpiModel(compartments, parameters)
end

function play(N::Int)
    return function (du, u, p, t)
        (S, E, I, H, _, _) = u
        (alpha, gamma, mu) = ./(1, p[end-2:end])
        beta = p[1] * p[2]

        dS =  beta * S * I / N
        dE = alpha * E
        dI = gamma * I
        dH =    mu * H

        du[1] =    - dS
        du[2] = dS - dE
        du[3] = dE - dI
        du[4] = dI - dH
        du[5] = (1 - p[3]) * dH
        du[6] =      p[3]  * dH
    end
end
