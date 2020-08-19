using
    CSV,
    DataFrames

include("epimodel.jl")

struct EpiData
    df::DataFrame
    population::Int
    lead_time::Int
end

function EpiData(file, model::EpiModel, population::Int;
                 lead_time::Int=1)
    df = CSV.File(file) |> DataFrame!
    df = select(sort(df, [:date]), observed(model);
                copycols=false)

    return EpiData(df, population, lead_time)
end

population(data::EpiData) = data.population
days(data::EpiData) = nrow(data.df)
duration(data::EpiData) = range(data.lead_time, length=days(data))
span(data::EpiData) = (0.0, maximum(duration(data)))
matrix(data::EpiData) = Matrix{Float64}(data.df)
