using Distributions

include("epimodel.jl")

function erl(mean, shape, lower, upper)
    rate = mean / shape
    return truncated(Erlang(shape, rate), lower, upper)
end

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
        (:r0,         truncated(Normal(2.2, 0.5), 0, 7)),
        (:population, Uniform(0.0, 0.1)),
        (:survival,   Uniform(0.0, 1.0)),
        (:incubation, LogNormal(1.63, 0.41)),
        (:infectious, erl(9, 20, 1, 20)),
        (:fatality,   erl(14, 10, 6, 40)),
    )

    return EpiModel(compartments, parameters)
end

function play(N::Int)
    return function (du, u, p, t)
        (S, E, I, H, _, _) = u
        (alpha, gamma, mu) = ./(1, p[end-2:end])
        (beta, population) = .*((gamma, N), p[1:2])

        dS = beta * S * I / population
        dE = alpha * E
        dI = gamma * I
        dH = (1 - p[3]) * dI

        du[5] = p[3] * dI
        du[6] = mu * H

        du[1] = -dS
        du[2] =  dS - dE
        du[3] =  dE - dH - du[5]
        du[4] =  dH - du[6]
    end
end
