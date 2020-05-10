import sys
import itertools as it
import multiprocessing as mp
from argparse import ArgumentParser

import pymc3 as pm
import pandas as pd
from scipy import constants
from scipy.integrate import solve_ivp

def transition(t, y, *args):
    (S, I, _, _) = y
    (N, beta, gamma, mu) = args

    dS = (beta * I * S) / N
    dR = gamma * I
    dD = mu * I
    dI = dS - dR - dD

    return (-dS, dI, dR, dD)

def fit(df, args):
    dayone = df.index.min()
    compartments = (
        'susceptible',
        'infected',
        'recovered',
        'deceased',
    )

    known = df.loc[dayone].to_dict()
    items = it.islice(compartments, 1, len(compartments))
    y0 = [
        args[0].random().item(),
    ]
    y0.extend(map(lambda x: known[x], items))

    span = df.index.max() - dayone
    duration = round(span.total_seconds() / constants.day)
    t_span = (0, duration)

    sol = solve_ivp(fun=transition,
                    y0=y0,
                    args=args,
                    t_span=t_span)
    if not sol.success:
        raise ArithmeticError(sol.message)

    return pd.DataFrame(data=sol.y.T,
                        index=sol.t,
                        columns=compartments)

arguments = ArgumentParser()
arguments.add_argument('--population', type=int, default=int(1e6))
args = arguments.parse_args()

df = pd.read_csv(sys.stdin, index_col='date', parse_dates=True)

with pm.Model() as model:
    N = pm.Poisson('N', mu=args.population)
    beta = pm.Uniform('beta', lower=0.25, upper=1)
    gamma = pm.Uniform('gamma', lower=1/7, upper=1/14)
    mu = pm.Uniform('mu', lower=1/1000, upper=1/3)

    ans = pm.Deterministic('ans', fit(df, (N, beta, gamma, mu)))

    trace = pm.sample(draw=10000,
                      cores=mp.cpu_count(),
                      target_accept=0.95)
