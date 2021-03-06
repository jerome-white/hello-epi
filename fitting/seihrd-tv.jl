include("epimodel.jl")
include("distutils.jl")

function BuildEpiModel()
    compartments = (
        (:susceptible,  false),
        (:exposed,      false),
        (:infected,     false),
        (:hospitalised, true),
        (:recovered,    true),
        (:deceased,     true),
        (:total,        true),
    )

    parameters = (
        #
        (:contacts,     GammaMeanStd(40, 20)),
        (:drift,        Gamma()),
        (:diffusion,    positive(Normal())),
        #
        (:transmission, Beta(2, 5)),
        (:fatality,     Beta(0.25, 4)),
        (:incubation,   GammaMeanVariance(5.5, 6.5)),
        (:infectious,   positive(CauchyIQR(IQR(5.7, 8.5)))),
        (:recovery,     GammaMeanVariance(9.1, 14.7)),
    )

    return EpiModel(compartments, parameters)
end

function play(N::Int)
    return function (du, u, p, t, W)
        (S, E, I, H) = u
        (trx, cfr) = p[4:5]
        (alpha, gamma, mu) = 1 ./ p[end-2:end]

        beta = W[1] * trx

        dS =  beta * S * I / N
        dE = alpha * E
        dI = gamma * I
        dH =    mu * H

        du[1] =    - dS
        du[2] = dS - dE
        du[3] = dE - dI
        du[4] = dI - dH
        du[5] = dH * (1 - cfr)
        du[6] = dH * cfr
        du[7] = dI
    end
end
