using
    CSV,
    Plots,
    DataFrames,
    DiffEqBayes,
    Distributions,
    DifferentialEquations

ENV["GKSwstype"] = "100"
# disable_logging(Logging.Warn)

function model(N)
    return function sird!(du, u, p, t)
        (S, I, _, _) = u
        (beta, gamma, mu) = p

        dS = beta * I * S / N

        du[1] = -dS
        du[3] = gamma * I
        du[4] = mu * I
        du[2] = dS - du[3] - du[4]
    end
end

function getdata(fp)
    compartments = [
        :susceptible,
        :infected,
        :deceased,
        :recovered,
    ]

    return select(sort(CSV.read(fp), [:date]), compartments, copycols=false)
end

function build(df)
    (rows, _) = size(df)

    ode = model(maximum(sum.(eachrow(df))))
    u0 = convert(Matrix, first(df, 1))
    tspan = (0.0, convert(Float64, rows))

    return ODEProblem(ode, u0, tspan)
end

function infer(df, prob)
    (rows, _) = size(df)

    rows -= 1
    data = convert(Matrix, last(df, rows))
    t = collect(range(1, stop=rows, length=rows))
    priors = [
        Uniform(0.0, 1.0), # beta
        Uniform(0.0, 1.0), # gamma
        Uniform(0.0, 1.0), # mu
    ]
    likelihood_dist_priors = [
        InverseGamma(2, 3), # S
        InverseGamma(2, 3), # I
        InverseGamma(2, 3), # R
        InverseGamma(2, 3), # D
    ]

    return turing_inference(prob, Rodas4P(), t, data, priors;
                            likelihood_dist_priors=likelihood_dist_priors,
                            progress=true,
                            num_samples=10)
end

df = getdata(stdin)
posterior = infer(df, build(df))

plot(posterior)
png("posterior.png")

CSV.write("posterior.csv", posterior)
