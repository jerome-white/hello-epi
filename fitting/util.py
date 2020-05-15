import os
import logging
import collections as cl

import pandas as pd
from pymc3.ode import DifferentialEquation

lvl = os.environ.get('PYTHONLOGLEVEL', 'WARNING').upper()
fmt = '[ %(asctime)s %(levelname)s %(process)d ] %(message)s'
logging.basicConfig(format=fmt, datefmt="%d %H:%M:%S", level=lvl)
# logging.getLogger('matplotlib').setLevel(logging.CRITICAL)
Logger = logging.getLogger(__name__)

Split = cl.namedtuple('Split', 'train, test')
def dsplit(df, outlook):
    y = df.index.max() - pd.DateOffset(days=outlook)
    x = y - pd.DateOffset(days=1)

    return Split(df.loc[:str(x)], df.loc[str(y):])

#
#
#
class EpiFitter:
    def __init__(self, epimodel, days):
        self.model = epimodel
        self.days = days

    def __len__(self):
        return self.days

    def solve(self, y0, theta):
        ode = DifferentialEquation(func=self.model,
                                   times=range(len(self)),
                                   n_states=len(self.model.compartments),
                                   n_theta=len(self.model.parameters),
                                   t0=0)

        return ode(y0=y0, theta=theta)

#
#
#
class EpiModel:
    def __call__(self, y, t, p):
        raise NotImplementedError()

    @property
    def compartments(self):
        raise NotImplementedError()

    @property
    def parameters(self):
        raise NotImplementedError()

class SIRD(EpiModel):
    def __init__(self, N):
        self.N = N

    def __call__(self, y, t, p):
        I = y[1]

        dS = (p[0] * I * y[0]) / self.N
        dR = p[1] * I
        dD = p[2] * I
        dI = dS - dR - dD

        return [ -dS, dI, dR, dD, ]

    @property
    def compartments(self):
        return (
            'susceptible',
            'infected',
            'recovered',
            'deceased',
        )

    @property
    def parameters(self):
        return (
            'beta',
            'gamma',
            'mu',
        )
