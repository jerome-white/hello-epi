import sys
import collections as cl
from argparse import ArgumentParser
from multiprocessing import Pool

import pandas as pd

Group = cl.namedtuple('Group', ['state', 'district'])

def func(args):
    (dis, group, df) = args

    view = (df
            .filter(items=['infected', 'recovered', 'deceased'])
            .resample('D')
            .ffill())
    if dis:
        view = view.diff().dropna()
    view = (view
            .clip(lower=0)
            .astype(int)
            .assign(**group._asdict()))

    return view

def each(fp, args):
    index = 'date'
    df = pd.read_csv(sys.stdin, index_col=index, parse_dates=[index])

    for (i, g) in df.groupby(list(Group._fields), sort=False):
        yield (args.disaggregate, Group(*i), g)

arguments = ArgumentParser()
arguments.add_argument('--workers', type=int)
arguments.add_argument('--disaggregate', action='store_true')
args = arguments.parse_args()

with Pool(args.workers) as pool:
    records = pool.imap_unordered(func, each(sys.stdin, args))
    pd.concat(records).to_csv(sys.stdout)
