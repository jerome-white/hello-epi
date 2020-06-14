import math
import operator as op
from pathlib import Path
from argparse import ArgumentParser

import pandas as pd
from scipy import constants

def get(args):
    keys = (
        'source',
        'target',
    )

    for i in keys:
        path = getattr(args, i)
        df = pd.read_csv(path,
                         index_col=args.date_column,
                         parse_dates=[args.date_column])

        yield df.index.min()

arguments = ArgumentParser()
arguments.add_argument('--source', type=Path)
arguments.add_argument('--target', type=Path)
arguments.add_argument('--date-column', default='date')
args = arguments.parse_args()

diff = op.sub(*get(args))
print(math.ceil(diff.total_seconds() / constants.day))
