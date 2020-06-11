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

        dS = beta * I * rho

        du[1] = -dS
        du[3] = gamma * I
        du[4] = mu * I
        du[2] = dS - du[3] - du[4]
    end
end
