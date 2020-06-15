using
    ArgParse,
    StatsPlots,
    MCMCChains

ENV["GKSwstype"] = "100"

function cliargs()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--trace"
        help = "File to dump Turing trace information"

        "--output"
        help = "Figure to generate"
    end

    return parse_args(s)
end

function main(args)
    chn = read(args["trace"], Chains)
    savefig(plot(chn), args["output"])
end

main(cliargs())
