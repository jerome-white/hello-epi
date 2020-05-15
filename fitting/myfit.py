import sys
import math
import pickle
import collections as cl
import multiprocessing as mp
from argparse import ArgumentParser

# import arviz as az
import pymc3 as pm
import pandas as pd
from pymc3.ode import DifferentialEquation
from scipy import constants

Split = cl.namedtuple('Split', 'train, test')

class EpiModel:
    _compartments = (
        'susceptible',
        'infected',
        'recovered',
        'deceased',
    )
    _parameters = (
        'beta',
        'gamma',
        'mu',
    )

    def __init__(self, df, N):
        assert len(df.columns) == len(self._compartments)

        dayone = df.index.min()
        span = df.index.max() - dayone

        self.N = N
        self.y0 = df.loc[dayone]
        self.observed = df.iloc[1:]
        self.duration = round(span.total_seconds() / constants.day)

    def __len__(self):
        return self.duration

    def transition(self, y, t, p):
        I = y[1]

        dS = (p[0] * I * y[0]) / self.N
        dR = p[1] * I
        dD = p[2] * I
        dI = dS - dR - dD

        return [ -dS, dI, dR, dD, ]

def dsplit(df, outlook):
    y = df.index.max() - pd.DateOffset(days=outlook)
    x = y - pd.DateOffset(days=1)

    return Split(df.loc[:str(x)], df.loc[str(y):])

arguments = ArgumentParser()
arguments.add_argument('--population', type=int, default=int(1e6))
arguments.add_argument('--prediction-days', type=int, default=0)
args = arguments.parse_args()

df = pd.read_csv(sys.stdin, index_col='date', parse_dates=True)
assert df.sum(axis='columns').le(args.population).all()
split = dsplit(df, args.prediction_days)

epi = EpiModel(split.train, args.population)
ode = DifferentialEquation(func=epi.transition,
                           times=range(len(epi)),
                           n_states=len(epi._compartments),
                           n_theta=len(epi._parameters),
                           t0=0)

obskey = 'Y'
datkey = 'observed'
scale = max(1, math.log(epi.observed.std().mean()))
with pm.Model() as model:
    #
    beta = pm.Uniform('beta', lower=0.05, upper=0.3)
    gamma = pm.Uniform('gamma', lower=1/30, upper=1/7)
    mu = pm.Uniform('mu', lower=0.001, upper=0.08)
    fit = ode(y0=epi.y0, theta=(beta, gamma, mu))

    #
    sigma = pm.HalfNormal('sigma', sigma=scale, shape=len(epi._compartments))
    Y = pm.Normal(obskey, mu=fit, sigma=sigma, observed=epi.observed)

    #
    posterior = pm.sample(cores=mp.cpu_count(),
                          target_accept=0.95)
    pm.trace_to_dataframe(posterior).to_csv(sys.stdout)

# with model:
#     posterior_pred = pm.sample_posterior_predictive(posterior)

# f = lambda x: pd.DataFrame(x, columns=EpiModel._compartments).reset_index()
# pd.concat(map(f, posterior_pred[obskey])).to_csv(sys.stdout, index=False)
