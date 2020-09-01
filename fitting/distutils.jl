using Distributions

#
#
#
struct IQR
    lower::Real
    upper::Real
end

width(iqr::IQR) = iqr.upper - iqr.lower
scale(iqr::IQR) = width(iqr) / 2
center(iqr::IQR) = iqr.upper - scale(iqr)

#
#
#
function positive(dist; lower::Real=0, upper::Real=Inf)
    return truncated(dist, lower, upper)
end

function CauchyIQR(iqr::IQR)
    return Cauchy(center(iqr), scale(iqr))
end

function GammaMeanStd(mean::Real, sigma::Real)
    alpha = (mean / sigma) ^ 2
    beta = sigma ^ 2 / mean

    return Gamma(alpha, beta)
end

function GammaMeanVariance(mean::Real, variance::Real)
    return GammaMeanStd(mean, sqrt(variance))
end
