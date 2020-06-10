from pathlib import Path
from argparse import ArgumentParser
from multiprocessing import Pool

from libepi import Logger

def func(args):
    contents = list(args.iterdir())
    if not any([ x.suffix.endswith('png') for x in contents ]):
        for i in contents:
            i.unlink()
        args.rmdir()

        return args

arguments = ArgumentParser()
arguments.add_argument('--results', type=Path, required=True)
arguments.add_argument('--workers', type=int)
args = arguments.parse_args()

with Pool(args.workers) as pool:
    for i in filter(None, pool.imap_unordered(func, args.results.iterdir())):
        Logger.warning('Cleaning {}'.format(i))
