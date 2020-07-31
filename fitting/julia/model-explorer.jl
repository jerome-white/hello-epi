using
    ArgParse,
    StatsPlots,
    MCMCChains

include("util.jl")

ENV["GKSwstype"] = "100"

function cliargs()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--chains"
        help = "Directory of chains"

        "--output"
        help = "Figure to generate"
    end

    return parse_args(s)
end

function main(args)
    chn = catchains(args["chains"])
    savefig(plot(chn), args["output"])
end

main(cliargs())
