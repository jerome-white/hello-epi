import sys
import math
import itertools as it
import collections as cl
from pathlib import Path
from argparse import ArgumentParser

import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
from scipy import constants

from util import Logger

arguments = ArgumentParser()
arguments.add_argument('--output', type=Path)
arguments.add_argument('--ground-truth', type=Path)
arguments.add_argument('--project', type=int)
arguments.add_argument('--with-susceptible', action='store_true')
args = arguments.parse_args()

gt = pd.read_csv(args.ground_truth, index_col='date', parse_dates=['date'])

#
#
#
index = 'day'
compartments = cl.deque([
    'infected',
    'recovered',
    'deceased',
])
if args.with_susceptible:
    compartments.appendleft('susceptible')
usecols = list(it.chain(compartments, [index]))
pr = pd.read_csv(sys.stdin, usecols=usecols)
if args.project is not None:
    diff = gt.index.max() - gt.index.min()
    days = math.ceil(diff.total_seconds() / constants.day)
    pr = pr.query('day <= {}'.format(days + args.project))
compartments = list(it.filterfalse(lambda x: x == index, pr.columns))
by = 'compartment'
pr = pr.melt(id_vars=[index], value_vars=compartments, var_name=by)

#
#
#
(_, axes) = plt.subplots(nrows=len(compartments), sharex=True) #, sharey=True)
palette = sns.color_palette()
for (ax, (c, g)) in zip(axes, pr.groupby(by, sort=False)):
    Logger.info(c)

    ax.plot(gt[c].to_numpy(),
            color=palette[1],
            marker='o',
            markeredgewidth=1.5,
            markeredgecolor='white')

    sns.lineplot(x=index,
                 y='value',
                 hue=by,
                 data=g,
                 ax=ax)

    ax.get_legend().remove()
    ax.grid(which='both')
    ax.set_xlabel('Day')
    ax.set_ylabel(c.title())
plt.savefig(args.output)
