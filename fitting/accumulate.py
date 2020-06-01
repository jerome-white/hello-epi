import sys
import csv
from argparse import ArgumentParser
from multiprocessing import Pool

import pandas as pd

from util import Logger

def func(args):
    (key, value, group) = args
    Logger.info(value)

    return (group
            .set_index('day')
            .sort_index()
            .drop(columns=key)
            .cumsum()
            .assign(**{key: value})
            .reset_index()
            .to_dict(orient='records'))

def get(fp):
    by = 'run'
    df = pd.read_csv(fp, memory_map=True)

    for i in df.groupby(by, sort=False):
        yield (by, *i)

arguments = ArgumentParser()
arguments.add_argument('--workers', type=int)
args = arguments.parse_args()

with Pool(args.workers) as pool:
    writer = None
    for i in pool.imap_unordered(func, get(sys.stdin)):
        if writer is None:
            head = i[0]
            writer = csv.DictWriter(sys.stdout, fieldnames=head)
            writer.writeheader()
        writer.writerows(i)
