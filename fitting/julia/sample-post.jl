using
    CSV,
    ArgParse,
    MCMCChains

# include("sird.jl")
include("ird.jl")

function cliargs()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--trace"
        help = "Trace file"

        "--samples"
        help = "Number of samples to take from the posterior"
        arg_type = Int
        default = nothing
    end

    return parse_args(s)
end

function nchain(chn)
    return size(chn, 3)
end

function eachchain(chn)
    Channel() do channel
        for i in 1:nchain(chn)
            put!(channel, chn[:, :, i])
        end
    end
end

function spread(chn, samples)
    m = length(chn)
    n = nchain(chn)

    if isnothing(samples)
        samples = m
    elseif samples > m * n
        @warn "Possible over sampling"
    end

    (across, within) = map(x -> x(samples, n), [÷, %])

    assignments = repeat([across], samples)
    for i in rand(1:samples, within)
        assignments[i] += 1
    end

    return assignments
end

function main(args)
    chn = read(args["trace"], Chains)
    assignments = spread(chn, args["samples"])

    results = DataFrame()
    for (i, j) in enumerate(eachchain(chn))
        items = sample(j, assignments[i])
        df = DataFrame(items)
        view = select(df, parameters, copycols=false)

        append!(results, view)
    end

    return results
end

CSV.write(stdout, main(cliargs()))
