using
    CSV,
    Turing,
    MCMCChains,
    DataFrames,
    DifferentialEquations

include("modeler.jl")

function load(file, model::EpiModel)
    df = CSV.File(file) |> DataFrame!
    return select(sort(df, [:date]), observed(model); copycols=false)
end

function catchains(dir::String)
    chains = Vector{Chains}()

    for (root, dirs, files) in walkdir(dir)
        for i in files
            file = joinpath(root, i)
            try
                push!(chains, read(file, Chains))
            catch err
                if isa(err, EOFError)
                    continue
                end
            end
        end
    end

    return reduce(chainscat, chains)
end

function solver(model::EpiModel, population::Int, duration::Int;
                lead_time::Int=1, initial_infected::Int=1)
    u0 = zeros(ncompartments(model))
    u0[3] = initial_infected
    u0[1] = population - sum(u0)

    t0 = 0.0
    saveat = range(lead_time, length=duration)
    tspan = (t0, maximum(saveat))
    compartments = reported(model)

    return function (p)
        (start, drift) = p[1:2]

        noise = GeometricBrownianMotionProcess(0, drift, t0, start)
        prob = RODEProblem(play(population), u0, tspan;
                           noise=noise,
                           rand_prototype=zeros(1))
        sol = solve(prob, RandomEM();
                    saveat=saveat,
                    p=p,
                    dt=1e-2)

        if sol.retcode == :Success
            results = view(sol, compartments, :)
            if all(results .> 0)
                return transpose(results)
            end
        end
    end
end

function solver(model::EpiModel, population::Int, df::DataFrame;
                lead_time::Int=1, initial_infected::Number=1)
    return solver(model, population, nrow(df);
                  lead_time=lead_time, initial_infected=initial_infected)
end
