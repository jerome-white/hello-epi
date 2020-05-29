import os
import logging
import collections as cl

import pandas as pd
from pymc3.ode import DifferentialEquation

lvl = os.environ.get('PYTHONLOGLEVEL', 'WARNING').upper()
fmt = '[ %(asctime)s %(levelname)s %(process)d ] %(message)s'
logging.basicConfig(format=fmt, datefmt="%d %H:%M:%S", level=lvl)
logging.getLogger('matplotlib').setLevel(logging.CRITICAL)
Logger = logging.getLogger(__name__)

Split = cl.namedtuple('Split', 'train, test')
def dsplit(df, outlook):
    y = df.index.max() - pd.DateOffset(days=outlook)
    x = y - pd.DateOffset(days=1)

    return Split(df.loc[:str(x)], df.loc[str(y):])

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

    def __init__(self, *args, **kwargs):
        pass

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

    def __init__(self, *args, **kwargs):
        if 'N' in kwargs:
            self.N = kwargs['N']
        elif not args:
            raise ValueError('Must supply population')
        else:
            self.N = args[0]

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
        'N',
        'beta',
        'gamma',
        'mu',
    )

    def __call__(self, y, t, p):
        I = y[1]

        dR = p[2] * I
        dD = p[3] * I
        dI = p[1] * I * p[0] - dR - dD

        return [ dI, dR, dD, ]
