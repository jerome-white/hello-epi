import sys
import math
import multiprocessing as mp
from pathlib import Path
from argparse import ArgumentParser

import pymc3 as pm
import pandas as pd
from scipy import constants

from util import EpiFitter, SIRD, Logger, dsplit

arguments = ArgumentParser()
arguments.add_argument('--trace', type=Path)
arguments.add_argument('--workers', type=int, default=mp.cpu_count())
args = arguments.parse_args()

#
# Aquire the data
#
df = (pd
      .read_csv(sys.stdin, index_col='date', parse_dates=True)
      .reindex(columns=SIRD._compartments))
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
# Explore!
#
with pm.Model() as model:
    #
    beta = pm.Uniform('beta', lower=0.05, upper=0.3)
    gamma = pm.Uniform('gamma', lower=1/30, upper=1/7)
    mu = pm.Uniform('mu', lower=0.001, upper=0.08)
    solution = fit(y0.to_numpy().ravel(), (beta, gamma, mu))

    #
    sigma = pm.HalfNormal('sigma',
                          sigma=observed.std(),
                          shape=len(epimodel.compartments))
    Y = pm.Normal('Y', mu=solution, sigma=sigma, observed=observed)

    #
    posterior = pm.sample(cores=mp.cpu_count(), target_accept=0.95)
    pm.trace_to_dataframe(posterior).to_csv(sys.stdout, index=False)
