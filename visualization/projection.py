import sys
import warnings
import operator as op
import functools as ft
import itertools as it
import collections as cl
from pathlib import Path
from argparse import ArgumentParser
from multiprocessing import Pool

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy import constants
from scipy.stats import bayes_mvs
from statsmodels.stats.weightstats import DescrStatsW

from libepi import Logger

#
#
#
Band = cl.namedtuple('Band', 'lower, upper')

class IntervalCalculator:
    def __init__(self, alpha):
        self.alpha = list(alpha)

    def __iter__(self):
        yield from self.alpha

    def __call__(self, alpha, df):
        raise NotImplementedError()

    def aggregate(self, df):
        raise NotImplementedError()

    @staticmethod
    def build(dtype, *args, **kwargs):
        available = {
            'quantile': QuantileCalculator,
            'credible': BayesCredibleCalculator,
            'confidence': ConfidenceIntervalCalculator,
        }

        if dtype not in available:
            raise TypeError('Unsupported confidence "{}"'.format(dtype))

        return available[dtype](*args, **kwargs)

class QuantileCalculator(IntervalCalculator):
    def __init__(self, alpha):
        # super().__init__(reversed(sorted(alpha)))
        super().__init__(sorted(alpha))

        self.mid = 0.5

    def __call__(self, alpha, df):
        if alpha > self.mid:
            raise ValueError('Invalid alpha {}'.format(alpha))
        calculate = lambda x: df.quantile(x(self.mid, alpha))

        return Band(*map(calculate, (op.sub, op.add)))

    def aggregate(self, df):
        return df.median()

class BayesCredibleCalculator(IntervalCalculator):
    def __init__(self, alpha):
        super().__init__(sorted(alpha))

    def __call__(self, alpha, df):
        with warnings.catch_warnings():
            warnings.simplefilter('error', RuntimeWarning)
            try:
                (mean, *_) = bayes_mvs(df, alpha=alpha)
            except RuntimeWarning:
                raise ValueError()
        (_, (lower, upper)) = mean

        return Band(lower, upper)

    def aggregate(self, df):
        return df.mean()

class ConfidenceIntervalCalculator(IntervalCalculator):
    def __init__(self, alpha):
        super().__init__(sorted(map(lambda x: 1 - x, alpha)))

    def __call__(self, alpha, df):
        stats = DescrStatsW(df)
        (lower, upper) = stats.tconfint_mean(alpha=alpha)

        return Band(lower, upper)

    def aggregate(self, df):
        return df.mean()

#
#
#
class Confidence:
    def __init__(self, icalc, index, workers=None):
        self.icalc = icalc
        self.index = index
        self.workers = workers

    def __call__(self, args):
        (alpha, index, group) = args
        try:
            band = self.icalc(alpha, group)
        except ValueError:
            return

        return {
            self.index: index,
            **band._asdict(),
        }

    def intervals(self, df, value):
        with Pool(self.workers) as pool:
            groups = df.groupby(self.index)

            for i in self.icalc:
                iterable = it.starmap(lambda x, y: (i, x, y[value]), groups)
                records = filter(None, pool.imap_unordered(self, iterable))
                data = (pd
                        .DataFrame
                        .from_records(records, index=self.index)
                        .sort_index())

                yield data

    def aggregate(self, df):
        return self.icalc.aggregate(df)

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
arguments.add_argument('--confidence', default='quantile')
arguments.add_argument('--output', type=Path)
arguments.add_argument('--ground-truth', type=Path)
arguments.add_argument('--training-days', type=int)
arguments.add_argument('--validation-days', type=int)
arguments.add_argument('--testing-days', type=int)
arguments.add_argument('--ci', action='append', type=float)
arguments.add_argument('--with-susceptible', action='store_true')
arguments.add_argument('--workers', type=int)
args = arguments.parse_args()

index = 'day'

#
#
#
idx = 'date'
assign = {
    'split': ft.partial(labeller, testing=args.validation_days),
    index: relative,
}
gt = (pd
      .read_csv(args.ground_truth, parse_dates=[idx])
      .melt(id_vars=[idx])
      .set_index(idx)
      .assign(**assign))
assert not gt.empty

#
#
#
pr = pd.read_csv(sys.stdin)

compartments = cl.deque([
    'infected',
    'recovered',
    'deceased',
])
if args.with_susceptible:
    compartments.appendleft('susceptible')
pr = pr.filter(items=it.chain(compartments, [index]))

days = gt[index].max()
if args.training_days is None:
    lower = 0
else:
    lower = days - args.validation_days - args.training + 1
upper = days + args.testing_days
gt = gt.query('{1} <= {0}'.format(index, lower))
pr = pr.query('{1} <= {0} <= {2}'.format(index, lower, upper))

compartments = list(it.filterfalse(lambda x: x == index, pr.columns))
by = 'compartment'
pr = pr.melt(id_vars=[index], value_vars=compartments, var_name=by)

#
#
#
(_, axes) = plt.subplots(nrows=len(compartments), sharex=True)

xticker = plt.FuncFormatter(ft.partial(xtickfmt, start=gt.index.min()))
yticker = plt.FuncFormatter(ytickfmt)

ci = IntervalCalculator.build(args.confidence, args.ci)
# ci = BayesCredibleCalculator(args.ci)
conf = Confidence(ci, index, args.workers)

gtdots = (
    ('train', 'g', 'o'),
    ('test', 'r', '+'),
)

for (ax, comp) in zip(axes, compartments):
    Logger.info(comp)
    g = (pr
         .query('{} == @comp'.format(by))
         .filter(items=[index, 'value']))

    # Uncertainty
    for i in conf.intervals(g, 'value'):
        ax.fill_between(i.index,
                        i['lower'],
                        i['upper'],
                        color='gray',
                        alpha=0.2)

    # Estimate
    agg = conf.aggregate(g.groupby(index))
    agg.plot.line(legend=False, ax=ax)

    # Actual data
    for (i, j, k) in gtdots:
        view = gt.query('variable == @comp and split == "{}"'.format(i))
        view.plot.scatter(x=index,
                          y='value',
                          s=15,
                          legend=False,
                          color=j,
                          ax=ax,
                          marker=k,
                          edgecolor='white')

    # Decorations
    ax.grid(which='both')
    ax.set_ylabel(comp.title())
    ax.xaxis.label.set_visible(False)
    ax.xaxis.set_major_formatter(xticker)
    ax.yaxis.set_major_formatter(yticker)
plt.tight_layout()
plt.savefig(args.output)
