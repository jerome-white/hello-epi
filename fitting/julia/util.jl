using
    CSV,
    DataFrames,
    DifferentialEquations

function load(fp, compartments)
    df = DataFrame!(CSV.File(fp))
    return select(sort(df, [:date]), compartments, copycols=false)
end

function solver(df::DataFrame, epimodel, duration::Number)
    u0 = Vector{Float64}(first(df))
    tspan = (0.0, duration - 1)

    return function (p)
        prob = ODEProblem(epimodel, u0, tspan)

        s = solve(prob, Rodas4P(); saveat=1, p=p)
        if s.retcode == :Success
            return s
        end
    end
end

function solver(df::DataFrame, epimodel)
    return solver(df, epimodel, nrow(df))
end
