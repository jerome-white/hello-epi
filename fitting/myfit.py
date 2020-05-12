#
# https://docs.pymc.io/notebooks/ODE_API_introduction.html
#

import sys
import collections as cl
import multiprocessing as mp
from argparse import ArgumentParser

import arviz as az
import pymc3 as pm
import pandas as pd
from pymc3.ode import DifferentialEquation
from scipy import constants

Compartments = cl.namedtuple('Compartments', [
    'susceptible',
    'infected',
    'recovered',
    'deceased',
])

Parameters = cl.namedtuple('Parameters', [
    'N',
    'beta',
    'gamma',
    'mu',
])

def transition(y, t, p):
    I = y[1]

    dS = (p[1] * I * y[0]) / p[0]
    dR = p[2] * I
    dD = p[3] * I
    dI = dS - dR - dD

    return [ -dS, dI, dR, dD, ]

arguments = ArgumentParser()
arguments.add_argument('--population', type=int, default=int(1e6))
args = arguments.parse_args()

df = (pd
      .read_csv(sys.stdin, index_col='date', parse_dates=True)
      .divide(args.population))

dayone = df.index.min()
span = df.index.max() - dayone
duration = round(span.total_seconds() / constants.day)
y0 = df.loc[dayone].to_numpy()

ode = DifferentialEquation(func=transition,
                           times=range(duration),
                           n_states=len(y0),
                           n_theta=len(Parameters._fields),
                           t0=0)

with pm.Model() as model:
    #
    N = pm.Poisson('N', mu=args.population)
    beta = pm.Uniform('beta', lower=1/4, upper=1)
    gamma = pm.Uniform('gamma', lower=1/14, upper=1/7)
    mu = pm.Uniform('mu', lower=1/10, upper=1/3)

    fit = ode(y0=y0, theta=(N, beta, gamma, mu))

    #
    sigma = pm.HalfNormal('sigma', sigma=1, shape=len(Compartments._fields))

    Y = pm.Normal('Y', mu=fit, sigma=sigma, observed=df.iloc[1:])

    #
    prior = pm.sample_prior_predictive()
    posterior = pm.sample(cores=mp.cpu_count())
    posterior_pred = pm.sample_posterior_predictive(posterior)

    # data = az.from_pymc3(trace=trace,
    #                      prior=prior,
    #                      posterior_predictive=posterior_predictive)
