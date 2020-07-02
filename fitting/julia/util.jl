using
    CSV,
    DataFrames,
    Distributions,
    DifferentialEquations

function load(fp, compartments)
    return select(sort(CSV.read(fp), [:date]), compartments, copycols=false)
end

function solver(u0::Vector{Float64}, duration::Number, epimodel)
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

function solver(df::DataFrame, epimodel, duration::Number)
    return solver(Vector{Float64}(first(df)), duration, epimodel)
end

function solver(df::DataFrame, epimodel)
    return solver(df, epimodel, nrow(df))
end

# https://github.com/cambridge-mlg/Covid19/blob/master/src/utils.jl
function NegativeBinomial2(mu, phi)
    p = 1 / (1 + mu / phi)
    r = phi

    return NegativeBinomial(r, p)
end
