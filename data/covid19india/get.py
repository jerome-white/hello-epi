import sys

import pandas as pd

date = 'date'
status = 'Status'

df = (pd
      .read_csv(sys.stdin,
                parse_dates=['Date'],
                infer_datetime_format=True)
      .rename(columns={'Date': date})
      .melt(id_vars=[date, 'Status'],
            var_name='state',
            value_name='count')
      .set_index(date)
      .assign(status=lambda x: x[status].str.lower())
      .drop(columns=status))
df.to_csv(sys.stdout)
