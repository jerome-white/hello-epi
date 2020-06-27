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
        help = "File to dump Turing trace information"

        "--samples"
        help = "Number of samples to take from the posterior"
        arg_type = Float64
        default = 1.0
    end

    return parse_args(s)
end

function main(args)
    chains = read(args["trace"], Chains)
    results = select(DataFrame(chains), parameters, copycols=false)

    if 0 < args["samples"] < 1
        samples = nrow(results)
        n = round(Int, samples * args["samples"])
        rows = sample(1:samples, n; replace=false)
        results = results[rows,:]
    end

    return results
end

CSV.write(stdout, main(cliargs()))
