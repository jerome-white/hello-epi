using
    CSV,
    DataFrames,
    DifferentialEquations

include("modeler.jl")

function load(file, model::EpiModel)
    df = CSV.File(file) |> DataFrame!
    return select(sort(df, [:date]), observed(model); copycols=false)
end

function solver(model::EpiModel, population::Int, duration::Int;
                lead_time::Int=1, initial_exposed::Number=1)
    u0 = zeros(ncompartments(model))
    u0[1] = population - initial_exposed
    u0[2] = initial_exposed

    saveat = range(lead_time, length=duration)
    tspan = (0.0, maximum(saveat))
    compartments = reported(model)

    return function (p)
        prob = ODEProblem(play(population), u0, tspan)
        sol = solve(prob, Rodas4P();
                    saveat=saveat, p=p)

        return sol.retcode == :Success ?
            permutedims(sol[compartments,:]) :
            nothing
    end
end

function solver(model::EpiModel, population::Int, df::DataFrame;
                lead_time::Int=1, initial_exposed::Number=1)
    return solver(model, population, nrow(df);
                  lead_time=lead_time, initial_exposed=initial_exposed)
end
