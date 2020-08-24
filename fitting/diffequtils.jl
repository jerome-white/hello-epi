using
    Statistics,
    DifferentialEquations

include("epidata.jl")
include("epimodel.jl")
include("modeler.jl")  # virtual package

#
#
#
function accrue(f, values::AbstractArray{T,3}) where T <: Real
    return dropdims(f(values; dims=3); dims=3)
end

function average(values::AbstractArray{T,3}) where T <: Real
    return accrue(mean, values)
end


#
#
#
struct DEParams
    iterations::Int
    dt_order::Int
    limit::Real
    acc
end

function DEParams(iterations::Int, dt_order::Int, limit::Real)
    return DEParams(iterations, dt_order, limit, average)
end
function DEParams(iterations::Int, dt_order::Int)
    return DEParams(iterations, dt_order, iterations)
end
DEParams() = DEParams(1, 0)

tsteps(params::DEParams) = 1 / 2 ^ params.dt_order
attempts(params::DEParams) = params.limit
trajectories(params::DEParams) = params.iterations

function accrue(params::DEParams, values::AbstractArray{T,3}) where T <: Real
    return params.acc(values)
end

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
    rows = active(data)
    columns = nobserved(model)
    iterations = trajectories(de_params)
    solutions = zeros(Real, rows, columns, iterations)

    dt = tsteps(de_params)
    limit = attempts(de_params)
    saveat = eachday(data)
    compartments = reported(model)

    let success = 0,
        failure = 0
        while success < iterations && failure < limit
            sol = solve(de_prob, RandomEM();
                        saveat=saveat,
                        p=parameters,
                        dt=dt)
            if sol.retcode == :Success
                results = @view sol[compartments,:]
                if all(results .>= 0)
                    success += 1
                    solutions[:,:,success] = transpose(results)
                    continue
                end
            end
            failure += 1
        end

        if success > 0
            relevant = @view solutions[:,:,1:success]
            return accrue(de_params, relevant)
        end
    end
end

function mknoise(data::EpiData, model::EpiModel, parameters)
    (start, drift, diffusion) = parameters

    tspan = startstop(data)
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