using
    Statistics,
    DifferentialEquations

include("epidata.jl")
include("epimodel.jl")
include("modeler.jl")  # virtual package

#
#
#
function agg(values::Array{T,3}, f) where T <: Real
    return dropdims(f(values; dims=3); dims=3)
end

function average(values::Array{T,3}) where T <: Real
    return agg(values, mean)
end

#
#
#
struct DEParams
    iterations::Int
    dt_order::Int
    limit::Real
    aggregate
end

function DEParams(iterations::Int, dt_order::Int, limit::Real)
    return DEParams(iterations, dt_order, limit, average)
end
DEParams(iterations::Int, dt_order::Int) = DEParams(iterations, dt_order, Inf)
DEParams() = DEParams(1, 0)

#
#
#
function initial(data::EpiData, model::EpiModel;
                 compartment::Int=2,
                 observed::Int=1)
    buckets = ncompartments(model)
    @assert 1 <= compartment <= buckets
    u0 = zeros(buckets)
    u0[compartment] = observed
    u0[1] = population(data) - sum(u0)
    @assert all(u0 .>= 0)

    return u0
end

function integrate(data::EpiData,
                   model::EpiModel,
                   parameters,
                   de_prob,
                   de_params::DEParams)
    rows = days(data)
    columns = nobserved(model)
    solutions = zeros(Real, rows, columns, de_params.iterations)

    saveat = duration(data)
    dt = 1 / 2 ^ de_params.dt_order
    # p = convert(Vector, parameters)

    compartments = reported(model)

    let success = 1,
        failure = 0
        while failure < de_params.limit
            sol = solve(de_prob, RandomEM();
                        saveat=saveat,
                        p=parameters,
                        dt=dt)
            if sol.retcode == :Success
                results = @view sol[compartments,:]
                if all(results .>= 0)
                    solutions[:,:,success] = transpose(results)
                    success += 1
                    if success > de_params.iterations
                        return de_params.aggregate(solutions)
                    end
                    continue
                end
            end
            failure += 1
        end
    end
end

function mknoise(data::EpiData, model::EpiModel, parameters)
    (start, drift, diffusion) = parameters

    tspan = span(data)
    t0 = minimum(tspan)
    noise = GeometricBrownianMotionProcess(drift, diffusion, t0, start)

    u0 = initial(data, model)
    ode = play(population(data))

    prob = RODEProblem(ode, u0, tspan;
                       noise=noise,
                       rand_prototype=zeros(1))

    return function (dep::DEParams)
        return integrate(data, model, parameters, prob, dep)
    end
end
