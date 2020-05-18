import sys
import math
import multiprocessing as mp

import pymc3 as pm
import pandas as pd
from scipy import constants

from util import EpiFitter, SIRD, Logger, dsplit

#
# Aquire the data
#
df = pd.read_csv(sys.stdin, index_col='date', parse_dates=True)
(y0, observed) = dsplit(df, len(df) - 2)

#
# Initialise the model
#
epimodel = SIRD(y0.squeeze().sum())
assert len(df.columns) == len(epimodel.compartments)

span = df.index.max() - df.index.min()
duration = round(span.total_seconds() / constants.day)
fit = EpiFitter(epimodel, duration)

#
# Establish PyMC3 model parameters
#
scale = max(1, math.log(observed.std().mean()))
shape = len(epimodel.compartments)

#
# Explore!
#
with pm.Model() as model:
    #
    beta = pm.Uniform('beta', lower=0.05, upper=0.3)
    gamma = pm.Uniform('gamma', lower=1/30, upper=1/7)
    mu = pm.Uniform('mu', lower=0.001, upper=0.08)
    sol = fit(y0.to_numpy().ravel(), (beta, gamma, mu))

    #
    sigma = pm.HalfNormal('sigma', sigma=scale, shape=shape)
    Y = pm.Normal('Y', mu=sol, sigma=sigma, observed=observed)

    #
    posterior = pm.sample(cores=mp.cpu_count(), target_accept=0.95)
    pm.trace_to_dataframe(posterior).to_csv(sys.stdout, index=False)
