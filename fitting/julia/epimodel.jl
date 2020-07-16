struct EpiModel
    c::Tuple#{Symbol,Bool}
    p::Tuple#{Symbol,UnionAll}
end

parameters(model::EpiModel) = collect(first.(model.p))
nparameters(model::EpiModel) = length(model.p)
priors(model::EpiModel) = model.p

compartments(model::EpiModel) = collect(first.(model.c))
ncompartments(model::EpiModel) = length(model.c)
observed(model::EpiModel) = collect(first.(filter(last, model.c)))
nobserved(model::EpiModel) = length(observed(model))

function reported(model::EpiModel)
    return first.(filter(last, collect(enumerate(last.(model.c)))))
end
