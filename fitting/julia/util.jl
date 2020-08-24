using
    MCMCChains

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
