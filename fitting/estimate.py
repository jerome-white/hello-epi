import sys
import math
import warnings
import multiprocessing as mp
from pathlib import Path
from argparse import ArgumentParser

import pymc3 as pm
import pandas as pd
import matplotlib.pyplot as plt
from scipy import constants

from util import EpiFitter, Logger, dsplit
# from util import SIRD as EpiModel
from util import IRD as EpiModel

arguments = ArgumentParser()
arguments.add_argument('--draws', type=int, default=1000)
arguments.add_argument('--tune', type=int)
arguments.add_argument('--population', type=int)
arguments.add_argument('--trace', type=Path)
arguments.add_argument('--workers', type=int, default=mp.cpu_count())
args = arguments.parse_args()

#
# Aquire the data
#
df = (pd
      .read_csv(sys.stdin, index_col='date', parse_dates=True)
      .reindex(columns=EpiModel._compartments))
y0 = df.iloc[0]

#
# Initialise the model
#
if args.population != y0.sum():
    warnings.warn('Population mismatch: {} vs {}'
                  .format(args.population, y0.sum()))
epimodel = EpiModel(args.population)

span = df.index.max() - df.index.min()
duration = round(span.total_seconds() / constants.day) + 1
fit = EpiFitter(epimodel, duration)

#
# Explore!
#
tune = args.draws // 2 if args.tune is None else args.tune

magnitude = math.floor(math.log10(df.sum(axis='columns').max()))
(lower, upper) = [ 10 ** (magnitude + x) for x in (1, 2) ]
Logger.debug('{} - {}'.format(lower, upper))

with pm.Model() as model:
    theta = (
        pm.Uniform('S', lower=lower, upper=upper), # !!!
        pm.Uniform('beta', lower=0, upper=1),
        pm.Uniform('gamma', lower=0, upper=1),
        pm.Uniform('mu', lower=0, upper=1),
    )
    solution = fit(y0.to_numpy().ravel(), theta)

    #
    sigma = pm.HalfNormal('sigma',
                          sigma=df.std(),
                          shape=len(epimodel._compartments))
    Y = pm.Normal('Y', mu=solution, sigma=sigma, observed=df)

    #
    posterior = pm.sample(draws=args.draws,
                          tune=tune,
                          cores=args.workers,
                          target_accept=0.95)
    pm.trace_to_dataframe(posterior).to_csv(sys.stdout, index=False)
    if args.trace is not None:
        pm.traceplot(posterior)
        plt.savefig(args.trace, bbox_inches='tight')
