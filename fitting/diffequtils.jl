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
abstract type AbstractDEParams end
struct StandardDEParams <: AbstractDEParams end
struct NoiseDEParams <: AbstractDEParams
    iterations::Int
    dt_order::Int
    limit::Real
    acc
end

function NoiseDEParams(iterations::Int, dt_order::Int, limit::Real)
    return NoiseDEParams(iterations, dt_order, limit, average)
end
function NoiseDEParams(iterations::Int, dt_order::Int)
    return NoiseDEParams(iterations, dt_order, iterations)
end
NoiseDEParams() = NoiseDEParams(1, 0)

tsteps(params::NoiseDEParams) = 1 / 2 ^ params.dt_order

attempts(params::AbstractDEParams) = 1
attempts(params::NoiseDEParams) = params.limit

trajectories(params::AbstractDEParams) = 1
trajectories(params::NoiseDEParams) = params.iterations

function accrue(params::NoiseDEParams,
                values::AbstractArray{T,3}) where T <: Real
    return params.acc(values)
end

struct DEConditions
    u0
    ode
    tspan
    saveat
end

function DEConditions(model::EpiModel, data::EpiData)
    return DEConditions(initial(data, model),
                        play(population(data)),
                        startstop(data),
                        eachday(data))
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

function integrate(model::EpiModel,
                   data::EpiData,
                   parameters::AbstractDEParams,
                   theta::AbstractArray{T,1}) where T <: Real
    sol = answer(model, data, parameters, theta)
    if !isnothing(sol)
        return transpose(sol)
    end
end

function answer(model::EpiModel,
                data::EpiData,
                parameters::StandardDEParams,
                theta)
    cond = DEConditions(model, data)
    prob = ODEProblem(cond.ode, cond.u0, cond.tspan)
    sol = solve(prob, Rodas4P();
                saveat=cond.saveat,
                p=theta)

    if sol.retcode == :Success
        compartments = reported(model)
        return sol[compartments,:]
    end
end

function answer(model::EpiModel,
                data::EpiData,
                parameters::NoiseDEParams,
                theta)
    rows = nobserved(model)
    columns = active(data)
    iterations = trajectories(parameters)
    solutions = zeros(Real, rows, columns, iterations)

    limit = attempts(parameters)
    compartments = reported(model)

    cond = DEConditions(model, data)
    t0 = minimum(cond.tspan)
    (start, drift, diffusion) = theta
    noise = GeometricBrownianMotionProcess(drift, diffusion, t0, start)
    prob = RODEProblem(cond.ode, cond.u0, cond.tspan;
                       noise=noise,
                       rand_prototype=zeros(1))

    dt = tsteps(parameters)

    let success = 0,
        failure = 0
        while success < iterations && failure < limit
            sol = solve(prob, RandomEM();
                        saveat=cond.saveat,
                        p=theta,
                        dt=dt)
            if sol.retcode == :Success
                results = @view sol[compartments,:]
                if all(results .>= 0)
                    success += 1
                    solutions[:,:,success] = results
                    continue
                end
            end
            failure += 1
        end

        if success > 0
            relevant = @view solutions[:,:,1:success]
            return accrue(parameters, relevant)
        end
    end
end
