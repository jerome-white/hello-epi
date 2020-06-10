using
    CSV,
    DataFrames,
    DifferentialEquations

function sird(N)
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

function load(fp)
    compartments = [
        :susceptible,
        :infected,
        :recovered,
        :deceased,
    ]

    return select(sort(CSV.read(fp), [:date]), compartments, copycols=false)
end

function solver(df, duration=nothing)
    if isnothing(duration)
        duration = nrow(df)
    end

    ode = sird(maximum(sum.(eachrow(df))))
    u0 = convert(Array, first(df, 1))
    tspan = (0.0, convert(Float64, duration))
    prob = ODEProblem(ode, u0, tspan)

    saveat = collect(range(1, stop=duration, length=duration))

    return function (p)
        s = solve(prob, Tsit5(); saveat=saveat, p=p)
        if s.retcode != :Success
            ErrorException(s.retcode)
        end

        return Matrix(vcat(s.u...))
    end
end
