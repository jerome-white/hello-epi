import sys
from argparse import ArgumentParser

import numpy as np
import pandas as pd

arguments = ArgumentParser()
arguments.add_argument('--population', type=int)
arguments.add_argument('--fraction', type=float, default=1)
arguments.add_argument('--with-variance', action='store_true')
args = arguments.parse_args()

df = pd.read_csv(sys.stdin, index_col='date', parse_dates=True)

f = np.random.poisson if args.with_variance else np.repeat
values = f(args.population, len(df)) * np.clip(args.fraction, 0, 1)
susceptible = (pd
               .Series(values, name='susceptible', index=df.index)
               .round())

df = pd.concat((susceptible, df), axis='columns')
df.to_csv(sys.stdout)
