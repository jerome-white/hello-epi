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

from libepi import Logger

from util import EpiFitter, DataHandler
from util import SIRD as EpiModel
# from util import IRD as EpiModel

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
handler = DataHandler.from_csv(sys.stdin, compartments=EpiModel._compartments)
y0 = handler.head()
observed = handler.tail()

#
# Initialise the model
#
if args.population != y0.sum():
    msg = 'Population mismatch: {} vs {} ({})'
    warnings.warn(msg.format(args.population, y0.sum(), y0.to_dict()))
epimodel = EpiModel(args.population)
fit = EpiFitter(epimodel, len(observed))

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
    solution = fit(y0, theta)

    #
    sigma = pm.HalfNormal('sigma',
                          sigma=observed.df.std(),
                          shape=len(epimodel._compartments))
    Y = pm.Normal('Y', mu=solution, sigma=sigma, observed=observed.df)

    #
    posterior = pm.sample(draws=args.draws,
                          tune=tune,
                          cores=args.workers,
                          target_accept=0.95)
    pm.trace_to_dataframe(posterior).to_csv(sys.stdout, index=False)
    if args.trace is not None:
        pm.traceplot(posterior)
        plt.savefig(args.trace, bbox_inches='tight')
