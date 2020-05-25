import sys
import json
from argparse import ArgumentParser
from urllib.parse import ParseResult
from multiprocessing import Pool, Queue

import requests
import pandas as pd

def func(incoming, outgoing):
    while True:
        (state, data) = incoming.get()
        state = state.casefold()

        for (k, values) in data.items():
            district = k.casefold()
            for i in values:
                observation = {
                    'state': state,
                    'district': district,
                }
                observation.update(i)
                outgoing.put(observation)
        outgoing.put(None)

def records(fp, args):
    incoming = Queue()
    outgoing = Queue()

    with Pool(args.workers, func, (outgoing, incoming)):
        url = ParseResult(scheme='https',
                          netloc='api.covid19india.org',
                          path=args.json,
                          query=None,
                          params=None,
                          fragment=None)
        raw = requests.get(url.geturl()).json().get(args.root)
        for i in raw.items():
            outgoing.put(i)

        completed = 0
        while completed < len(raw):
            observation = incoming.get()
            if observation is None:
                completed += 1
            else:
                yield observation

arguments = ArgumentParser()
arguments.add_argument('--root', default='districtsDaily')
arguments.add_argument('--date-column', default='date')
arguments.add_argument('--json', default='districts_daily.json')
arguments.add_argument('--workers', type=int)
args = arguments.parse_args()

df = (pd
      .DataFrame
      .from_records(records(sys.stdin, args))
      .astype({ args.date_column: 'datetime64[D]' })
      .set_index(args.date_column))
df.to_csv(sys.stdout)
