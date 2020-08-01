using Distributions

#
#
#
struct IQR
    lower::Number
    upper::Number
end

span(iqr::IQR) = iqr.upper - iqr.lower
scale(iqr::IQR) = span(iqr) / 2
center(iqr::IQR) = iqr.upper - scale(iqr)

#
#
#
function positive(dist; lower::Number=0, upper::Number=Inf)
    return truncated(dist, lower, upper)
end

function CauchyIQR(iqr::IQR)
    return positive(Cauchy(center(iqr), scale(iqr)))
end

function GammaMeanStd(mean::Number, sigma::Number)
    alpha = (mean / sigma) ^ 2
    beta = sigma ^ 2 / mean

    return Gamma(alpha, beta)
end

function GammaMeanVariance(mean::Number, variance::Number)
    return GammaMeanStd(mean, sqrt(variance))
end
