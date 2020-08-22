using
    CSV,
    DataFrames

include("epimodel.jl")

struct EpiData
    df::DataFrame
    population::Int
    past::Int
    future::Int
end

function EpiData(file, model::EpiModel, population::Int;
                 past::Int=1,
                 future::Int=0)
    df = CSV.File(file) |> DataFrame!
    df = select(sort(df, [:date]), observed(model);
                copycols=false)

    return EpiData(df, population, past, future)
end

population(data::EpiData) = data.population

past(data::EpiData) = data.past
present(data::EpiData) = nrow(data.df)
future(data::EpiData) = data.future
active(data::EpiData) = present(data) + future(data)
eachday(data::EpiData) = range(past(data), length=active(data))
startstop(data::EpiData) = (0.0, maximum(eachday(data)))

matrix(data::EpiData) = Matrix{Float64}(data.df)
