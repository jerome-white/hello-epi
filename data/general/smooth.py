import sys
from argparse import ArgumentParser

import pandas as pd

arguments = ArgumentParser()
arguments.add_argument('--window', type=int)
arguments.add_argument('--date-column', default='date')
args = arguments.parse_args()

df = (pd
      .read_csv(sys.stdin,
                index_col=args.date_column,
                parse_dates=[args.date_column])
      .rolling(args.window, center=True)
      .mean()
      .dropna()
      .round()
      .astype(int))
df.to_csv(sys.stdout)
