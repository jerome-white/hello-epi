import os
import logging
import collections as cl

import pandas as pd
from scipy import constants
from pymc3.ode import DifferentialEquation

lvl = os.environ.get('PYTHONLOGLEVEL', 'WARNING').upper()
fmt = '[ %(asctime)s %(levelname)s %(process)d ] %(message)s'
logging.basicConfig(format=fmt, datefmt="%d %H:%M:%S", level=lvl)
logging.getLogger('matplotlib').setLevel(logging.CRITICAL)
logging.captureWarnings(True)
Logger = logging.getLogger(__name__)

class DataHandler:
    def __init__(self, df):
        self.df = df

    def head(self):
        return self.df.iloc[0]

    def tail(self):
        return type(self)(self.df.iloc[1:])

    def __len__(self):
        span = self.df.index.max() - self.df.index.min()
        return round(span.total_seconds() / constants.day) + 1

    @classmethod
    def from_csv(cls, fp, index='date', compartments=None):
        df = (pd
              .read_csv(fp, index_col=index, parse_dates=[index])
              .sort_index())
        if compartments is not None:
            df = df.reindex(columns=compartments)

        return cls(df)

#
#
#
class EpiFitter(DifferentialEquation):
    def __init__(self, epimodel, days):
        super().__init__(func=epimodel,
                         times=range(days),
                         n_states=len(epimodel._compartments),
                         n_theta=len(epimodel._parameters))

#
#
#
class EpiModel:
    _compartments = None
    _parameters = None

    def __init__(self, N):
        self.N = N

    def __call__(self, y, t, p):
        raise NotImplementedError()

class SIRD(EpiModel):
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

    def __call__(self, y, t, p):
        I = y[1]

        dS = (p[0] * I * y[0]) / self.N
        dR = p[1] * I
        dD = p[2] * I
        dI = dS - dR - dD

        return [ -dS, dI, dR, dD, ]

class IRD(EpiModel):
    _compartments = (
        'infected',
        'recovered',
        'deceased',
    )

    _parameters = (
        'S',
        'beta',
        'gamma',
        'mu',
    )

    def __call__(self, y, t, p):
        I = y[0]

        dS = (p[1] * I * p[0]) / self.N
        dR = p[2] * I
        dD = p[3] * I
        dI = dS - dR - dD

        return [ dI, dR, dD, ]
