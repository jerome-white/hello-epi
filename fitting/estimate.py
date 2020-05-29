import sys
import math
import multiprocessing as mp
from pathlib import Path
from argparse import ArgumentParser

import pymc3 as pm
import pandas as pd
import matplotlib.pyplot as plt
from scipy import constants

from util import EpiFitter, Logger, dsplit
from util import SIRD as EpiModel

arguments = ArgumentParser()
arguments.add_argument('--trace', type=Path)
arguments.add_argument('--workers', type=int, default=mp.cpu_count())
args = arguments.parse_args()

#
# Aquire the data
#
df = (pd
      .read_csv(sys.stdin, index_col='date', parse_dates=True)
      .reindex(columns=EpiModel._compartments))
(y0, observed) = dsplit(df, len(df) - 2)

#
# Initialise the model
#
epimodel = EpiModel(N=y0.squeeze().sum())

span = df.index.max() - df.index.min()
duration = round(span.total_seconds() / constants.day)
fit = EpiFitter(epimodel, duration)

#
# Explore!
#
with pm.Model() as model:
    #
    beta = pm.Uniform('beta', lower=0, upper=10)
    gamma = pm.Uniform('gamma', lower=0, upper=10)
    mu = pm.Uniform('mu', lower=0, upper=10)
    solution = fit(y0.to_numpy().ravel(), (beta, gamma, mu))

    #
    sigma = pm.HalfNormal('sigma',
                          sigma=observed.std(),
                          shape=len(epimodel._compartments))
    Y = pm.Normal('Y', mu=solution, sigma=sigma, observed=observed)

    #
    posterior = pm.sample(cores=args.workers, target_accept=0.95)
    pm.trace_to_dataframe(posterior).to_csv(sys.stdout, index=False)
    if args.trace is not None:
        pm.traceplot(posterior)
        plt.savefig(args.trace, bbox_inches='tight')
