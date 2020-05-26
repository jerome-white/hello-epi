import sys
from argparse import ArgumentParser

import numpy as np
import pandas as pd

class Susceptible:
    def __init__(self, population):
        self.population = population

    def __call__(self, x):
        values = np.repeat(self.population, len(x))
        return np.subtract(values, x.sum(axis='columns'))

arguments = ArgumentParser()
arguments.add_argument('--state', action='append')
arguments.add_argument('--district', action='append')
arguments.add_argument('--population', type=int, required=True)
args = arguments.parse_args()

#
#
#
index = 'date'
compartments = [
    'infected',
    'deceased',
    'recovered',
]
usecols = [
    index,
    'state',
    'district',
]
usecols.extend(compartments)
df = pd.read_csv(sys.stdin,
                 index_col=index,
                 parse_dates=[index],
                 usecols=usecols)

#
#
#
query = []
for i in ('state', 'district'):
    value = getattr(args, i)
    if value:
        j = ','.join(map('"{}"'.format, value))
        query.append('{} in ({})'.format(i, j))
if query:
    df = df.query(' and '.join(query))

#
#
#
susceptible = Susceptible(args.population)
df = (df
      .filter(items=compartments)
      .assign(susceptible=susceptible))

#
#
#
df.to_csv(sys.stdout)
