import sys
import json
from argparse import ArgumentParser

import pandas as pd

def records(fp, root):
    raw = json.load(fp).get(root)

    for (i, data) in raw.items():
        state = i.casefold()
        for (j, values) in data.items():
            district = j.casefold()
            for i in values:
                v = {
                    'state': state,
                    'district': district,
                }
                v.update(i)

                yield v

arguments = ArgumentParser()
arguments.add_argument('--root', default='districtsDaily')
arguments.add_argument('--date-column', default='date')
args = arguments.parse_args()

df = (pd
      .DataFrame
      .from_records(records(sys.stdin, args.root))
      .astype({ args.date_column: 'datetime64[D]' })
      .set_index(args.date_column))
df.to_csv(sys.stdout)
