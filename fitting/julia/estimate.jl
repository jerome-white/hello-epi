using
    CSV,
    Optim,
    Turing,
    DataFrames,
    Distributions,
    DifferentialEquations

# disable_logging(Logging.Warn)

function sird(N)
    return function (du, u, p, t)
        (S, I, _, _) = u
        (beta, gamma, mu) = p

        dS = beta * I * S / N

        du[1] = -dS
        du[3] = gamma * I
        du[4] = mu * I
        du[2] = dS - du[3] - du[4]
    end
end

function load(fp)
    compartments = [
        :susceptible,
        :infected,
        :deceased,
        :recovered,
    ]

    return select(sort(CSV.read(fp), [:date]), compartments, copycols=false)
end

function solver(df)
    steps = nrow(df)

    ode = sird(maximum(sum.(eachrow(df))))
    u0 = convert(Array, first(df, 1))
    tspan = (0.0, convert(Float64, steps))
    prob = ODEProblem(ode, u0, tspan)

    saveat = collect(range(1, stop=steps, length=steps))

    return function (p)
        s = solve(prob, Tsit5(); saveat=saveat, p=p)
        if s.retcode != :Success
            ErrorException(s.retcode)
        end

        return Matrix(vcat(s.u...))
    end
end

function learn(data, observe)
    @model f(x, ::Type{T} = Float64) where {T} = begin
        # priors
        beta ~ Uniform(0.0, 1.0)
        gamma ~ Uniform(0.0, 1.0)
        mu ~ Uniform(0.0, 1.0)
        view = observe([beta, gamma, mu])

        # likelihood priors
        sigma = Vector{Float64}(undef, size(view, 2))
        for i in length(sigma)
            sigma ~ InverseGamma(2, 3)
        end

        # likelihood
        for i in 1:size(view, 1)
            x[i,:] ~ MvNormal(view[i,:], sqrt(sigma))
        end
    end

    return sample(f(data), NUTS(0.65), 1000)
end

function main(fp)
    df = convert.(Float64, load(fp))
    ode = solver(df)
    # data = convert(Matrix, last(df, nrow(df) - 1))
    data = convert(Matrix, df)
    estimates = learn(data, ode)
    write("estimates.jls", estimates)
end

main(stdin)
