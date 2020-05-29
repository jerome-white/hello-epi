import sys
import csv
from pathlib import Path
from argparse import ArgumentParser
from multiprocessing import Pool, Queue

import pandas as pd

from util import EpiFitter, SIRD, Logger

def func(incoming, outgoing, args):
    index = 'date'
    y0 = (pd
          .read_csv(args.data, index_col=index, parse_dates=[index])
          .reindex(columns=SIRD._compartments)
          .sort_index()
          .iloc[0]
          .to_numpy())

    model = SIRD(y0.sum())
    fit = EpiFitter(model, args.outlook)

    while True:
        params = incoming.get()
        theta = [ params[x] for x in model._parameters ]
        Logger.info(
            ' '.join(map(': '.join, zip(model._parameters, map(str, theta))))
        )
        data = fit(y0, theta).eval()
        df = (pd
              .DataFrame(data=data,
                         columns=model._compartments,
                         index=range(args.outlook))
              .reset_index()
              .rename(columns={'index': 'day'})
              .to_dict(orient='records'))

        outgoing.put(df)

arguments = ArgumentParser()
arguments.add_argument('--data', type=Path)
arguments.add_argument('--outlook', type=int)
arguments.add_argument('--workers', type=int)
args = arguments.parse_args()

incoming = Queue()
outgoing = Queue()
initargs = (
    outgoing,
    incoming,
    args,
)

with Pool(args.workers, func, initargs):
    records = 0
    reader = csv.DictReader(sys.stdin)
    for row in reader:
        outgoing.put({ x: float(y) for (x, y) in row.items() })
        records += 1

    writer = None
    for _ in range(records):
        result = incoming.get()
        if writer is None:
            head = result[0]
            writer = csv.DictWriter(sys.stdout, fieldnames=head.keys())
            writer.writeheader()
        writer.writerows(result)
