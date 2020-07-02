using
    CSV,
    DataFrames,
    DifferentialEquations

function load(fp, compartments)
    df = DataFrame!(CSV.File(fp))
    return select(sort(df, [:date]), compartments, copycols=false)
end

function solver(u0::Vector{Float64}, duration::Number, epimodel)
    tspan = (0.0, convert(Float64, duration - 1))

    return function (p)
        prob = ODEProblem(epimodel, u0, tspan)

        s = solve(prob, Rodas4P(); saveat=1, p=p)
        if s.retcode != :Success
            ErrorException(String(s.retcode))
        end

        return s
    end
end

function solver(df::DataFrame, duration::Number, epimodel)
    return solver(Vector{Float64}(first(df)), duration, epimodel)
end

function solver(df::DataFrame, epimodel)
    return solver(df, nrow(df), epimodel)
end
