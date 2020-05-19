import sys
from argparse import ArgumentParser

import pandas as pd

arguments = ArgumentParser()
arguments.add_argument('--window', type=int)
args = arguments.parse_args()

df = (pd
      .read_csv(sys.stdin, index_col='date', parse_dates=['date'])
      .rolling(args.window, center=True, win_type='gaussian')
      .mean(std=1)
      .dropna()
      .round()
      .astype(int))
df.to_csv(sys.stdout)
