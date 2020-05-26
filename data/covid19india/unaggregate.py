import sys
import collections as cl
from argparse import ArgumentParser
from multiprocessing import Pool

import pandas as pd

Group = cl.namedtuple('Group', ['state', 'district'])

def func(args):
    (group, df) = args

    return (df
            .filter(items=['infected', 'recovered', 'deceased'])
            .resample('D')
            .ffill()
            # .diff()
            # .fillna(0)
            .clip(lower=0)
            .astype(int)
            .assign(**group._asdict()))

def each(fp):
    index = 'date'
    df = pd.read_csv(sys.stdin, index_col=index, parse_dates=[index])

    for (i, g) in df.groupby(list(Group._fields), sort=False):
        yield (Group(*i), g)

arguments = ArgumentParser()
arguments.add_argument('--workers', type=int)
args = arguments.parse_args()

with Pool(args.workers) as pool:
    records = pool.imap_unordered(func, each(sys.stdin))
    pd.concat(records).to_csv(sys.stdout)
