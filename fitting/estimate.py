import sys
import math
import multiprocessing as mp
from argparse import ArgumentParser

# import arviz as az
import pymc3 as pm
import pandas as pd
from scipy import constants

from util import EpiFitter, SIRD, dsplit

arguments = ArgumentParser()
arguments.add_argument('--population', type=int, default=int(1e6))
args = arguments.parse_args()

#
# Aquire the data
#
df = pd.read_csv(sys.stdin, index_col='date', parse_dates=True)
assert df.sum(axis='columns').le(args.population).all()

#
# Initialise the model
#
epimodel = SIRD(args.population)
assert len(df.columns) == len(epimodel.compartments)

span = df.index.max() - df.index.min()
duration = round(span.total_seconds() / constants.day)
fit = EpiFitter(epimodel, duration)

#
# Establish PyMC3 model parameters
#
(y0, observed) = dsplit(df, len(df) - 2)
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
    sol = fit.solve(y0.to_numpy().ravel(), (beta, gamma, mu))

    #
    sigma = pm.HalfNormal('sigma', sigma=scale, shape=shape)
    Y = pm.Normal('Y', mu=sol, sigma=sigma, observed=observed)

    #
    posterior = pm.sample(cores=mp.cpu_count(),
                          target_accept=0.95)
    pm.trace_to_dataframe(posterior).to_csv(sys.stdout, index=False)
