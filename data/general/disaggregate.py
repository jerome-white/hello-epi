import sys

import pandas as pd

index = 'date'
df = (pd
      .read_csv(sys.stdin, index_col=index, parse_dates=[index])
      .diff()
      .dropna()
      .clip(lower=0)
      .round()
      .astype(int))
df.to_csv(sys.stdout)
