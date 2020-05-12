import sys
from argparse import ArgumentParser

import pandas as pd

arguments = ArgumentParser()
arguments.add_argument('--state', required=True)
args = arguments.parse_args()

df = (pd
      .read_csv(sys.stdin, parse_dates=['date'])
      .query('state == "{}"'.format(args.state.upper()))
      .pivot(index='date',
             columns='status',
             values='count')
      .rename(columns={'confirmed': 'infected'}))
if df.empty:
    raise ValueError('No data! Likely an invalid state: "{}"'
                     .format(args.state))
df.to_csv(sys.stdout)
