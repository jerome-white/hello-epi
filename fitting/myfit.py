import sys
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
        'N',
        'beta',
        'gamma',
        'mu',
    )

    def __init__(self, df):
        assert len(df.columns) == len(self._compartments)

        dayone = df.index.min()
        span = df.index.max() - dayone

        self.y0 = df.loc[dayone]
        self.observed = df.iloc[1:]
        self.duration = round(span.total_seconds() / constants.day)

    def __len__(self):
        return self.duration

    @staticmethod
    def transition(y, t, p):
        I = y[1]

        dS = (p[1] * I * y[0]) / p[0]
        dR = p[2] * I
        dD = p[3] * I
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

df = pd.read_csv(sys.stdin,
                 index_col='date',
                 parse_dates=True)
split = dsplit(df, args.prediction_days)

epi = EpiModel(split.train)
ode = DifferentialEquation(func=epi.transition,
                           times=range(len(epi)),
                           n_states=len(epi._compartments),
                           n_theta=len(epi._parameters),
                           t0=0)

obskey = 'Y'
datkey = 'observed'
with pm.Model() as model:
    #
    N = pm.Poisson('N', mu=args.population)
    beta = pm.Uniform('beta', lower=1/4, upper=1)
    gamma = pm.Uniform('gamma', lower=1/14, upper=1/7)
    mu = pm.Uniform('mu', lower=1/10, upper=1/3)

    fit = ode(y0=epi.y0, theta=(N, beta, gamma, mu))

    #
    sigma = pm.HalfNormal('sigma', sigma=1, shape=len(epi._compartments))
    observed = pm.Data(datkey, epi.observed)

    Y = pm.Normal(obskey, mu=fit, sigma=sigma, observed=observed)

    #
    posterior = pm.sample(cores=mp.cpu_count())

with model:
    pm.set_data({
        datkey: df,
    })
    posterior_pred = pm.sample_posterior_predictive(posterior)

f = lambda x: pd.DataFrame(x, columns=EpiModel._compartments).reset_index()
pd.concat(map(f, posterior_pred[obskey])).to_csv(sys.stdout, index=False)
