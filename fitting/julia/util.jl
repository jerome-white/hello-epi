using
    CSV,
    DifferentialEquations

function load(fp, compartments)
    return select(sort(CSV.read(fp), [:date]), compartments, copycols=false)
end

function solver(df, epimodel, duration=nothing)
    if isnothing(duration)
        duration = nrow(df)
    end

    u0 = convert(Array, first(df, 1))
    tspan = (0.0, convert(Float64, duration))
    prob = ODEProblem(epimodel, u0, tspan)

    saveat = collect(range(1, stop=duration, length=duration))

    return function (p)
        s = solve(prob, Tsit5(); saveat=saveat, p=p)
        if s.retcode != :Success
            ErrorException(s.retcode)
        end

        return s
    end
end
