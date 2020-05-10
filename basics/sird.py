# The SIRD model
# http://dx.doi.org/10.11648/j.acm.20150404.19
# https://en.wikipedia.org/wiki/Compartmental_models_in_epidemiology#The_SIRD_model
#

from pathlib import Path
from argparse import ArgumentParser

import pandas as pd
import matplotlib.pyplot as plt
from scipy.integrate import solve_ivp

class SIRD:
    _compartments = (
        'S',
        'I',
        'R',
        'D',
    )

    def __init__(self, N):
        self.N = N

    def __call__(self, t, y, *args):
        (S, I, _, _) = y
        (beta, gamma, mu) = args

        dS = (beta * I * S) / self.N
        dR = gamma * I
        dD = mu * I
        dI = dS - dR - dD

        return (-dS, dI, dR, dD)

    @property
    def start(self):
        i = self.N * 0.001
        r = self.N * 0.002
        s = self.N - i - r
        y0 = (s, i, r, 0)

        args = (
            0.4,   # infection
            0.035, # recovery
            0.005, # mortality
        )

        return (y0, args)

arguments = ArgumentParser()
arguments.add_argument('--days', type=int, default=60)
arguments.add_argument('--population', type=int, default=int(1e6))
arguments.add_argument('--output', type=Path)
args = arguments.parse_args()

sird = SIRD(args.population)
(y0, params) = sird.start
t_span = (0, args.days)

sol = solve_ivp(fun=sird,
                y0=y0,
                args=params,
                t_span=t_span)
if not sol.success:
    raise ArithmeticError(sol.message)

dynamics = pd.DataFrame(data=sol.y.T,
                        index=sol.t,
                        columns=sird._compartments)
dynamics.plot(grid=True)
plt.savefig(args.output)
