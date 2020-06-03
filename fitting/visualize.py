import sys
import math
import functools as ft
import itertools as it
import collections as cl
from pathlib import Path
from argparse import ArgumentParser

import numpy as np
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
from scipy import constants

from util import Logger

def labeller(x, testing):
    days = pd.Timedelta(testing, unit='D')
    pivot = x.index.max() - days
    return np.where(x.index > pivot, 'test', 'train')

def relative(x):
    diff = x.index - x.index.min()
    return (diff
            .to_series()
            .apply(lambda y: y.total_seconds() / constants.day)
            .to_numpy())

def xtickfmt(x, pos, start):
    tick = start + pd.Timedelta(x, unit='D')
    return tick.strftime('%d-%b')

# https://stackoverflow.com/a/1205664
def ytickfmt(x, pos):
    y = abs(x)
    support = (
         '',
	'K',
	'M',
	'B',
	'T',
    )
    iterable = it.starmap(lambda x, y: (x * 3, y), enumerate(support))

    for (i, j) in reversed(list(iterable)):
        mag = 10 ** i
        if y >= mag:
            return '{:.0f}{}'.format(x / mag, j)

arguments = ArgumentParser()
arguments.add_argument('--output', type=Path)
arguments.add_argument('--ground-truth', type=Path)
arguments.add_argument('--project', type=int)
arguments.add_argument('--sample', type=int)
arguments.add_argument('--testing-days', type=int)
arguments.add_argument('--with-susceptible', action='store_true')
args = arguments.parse_args()

#
#
#
index = 'date'
gt = (pd
      .read_csv(args.ground_truth, parse_dates=[index])
      .melt(id_vars=[index])
      .set_index(index)
      .assign(split=ft.partial(labeller, testing=args.testing_days),
              days=relative))

#
#
#
pr = pd.read_csv(sys.stdin)

if args.sample is not None:
    col = 'run'
    a = pr[col].unique()
    sample = np.random.choice(a, size=args.sample, replace=False)
    pr = pr.query('{} in @sample'.format(col))

index = 'day'
compartments = cl.deque([
    'infected',
    'recovered',
    'deceased',
])
if args.with_susceptible:
    compartments.appendleft('susceptible')
pr = pr.filter(items=it.chain(compartments, [index]))

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

xticker = plt.FuncFormatter(ft.partial(xtickfmt, start=gt.index.min()))
yticker = plt.FuncFormatter(ytickfmt)

for (ax, (c, g)) in zip(axes, pr.groupby(by, sort=False)):
    Logger.info(c)

    sns.lineplot(x=index,
                 y='value',
                 data=g,
                 legend=False,
                 ax=ax)

    view = gt.query('variable == "{}"'.format(c))
    n_colors = len(view['split'].unique())
    palette = sns.color_palette(palette='Set2', n_colors=n_colors)
    sns.scatterplot(x='days',
                    y='value',
                    hue='split',
                    data=view,
                    legend=False,
                    palette=palette,
                    ax=ax)

    ax.grid(which='both')
    ax.set_ylabel(c.title())
    ax.xaxis.label.set_visible(False)
    ax.xaxis.set_major_formatter(xticker)
    ax.yaxis.set_major_formatter(yticker)
plt.savefig(args.output)
