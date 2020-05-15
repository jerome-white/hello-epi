import sys
import itertools as it
import collections as cl
from pathlib import Path
from argparse import ArgumentParser

import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt

arguments = ArgumentParser()
arguments.add_argument('--output', type=Path)
arguments.add_argument('--with-susceptible', action='store_true')
args = arguments.parse_args()

index = 'day'
compartments = cl.deque([
    'infected',
    'recovered',
    'deceased',
])
if args.with_susceptible:
    compartments.appendleft('susceptible')
ctitle = 'Compartment'

usecols = list(it.chain(compartments, [index]))
df = pd.read_csv(sys.stdin, usecols=usecols)
compartments = list(it.filterfalse(lambda x: x == index, df.columns))
df = df.melt(id_vars=[index], value_vars=compartments, var_name=ctitle)

sns.lineplot(x=index,
             y='value',
             hue=ctitle,
             data=df)
plt.grid(which='both')
plt.xlabel('Day')
plt.ylabel('Population')
plt.savefig(args.output)
