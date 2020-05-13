import sys
from pathlib import Path
from argparse import ArgumentParser

import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt

arguments = ArgumentParser()
arguments.add_argument('--output', type=Path)
args = arguments.parse_args()

index = 'index'
kwargs = {
    'x': 'Day',
    'y': 'Population',
    'hue': 'Compartment',
}

df = pd.read_csv(sys.stdin)
compartments = list(filter(lambda x: x != index, df.columns))
df = (df
      .melt(id_vars=[index],
            value_vars=compartments,
            var_name=kwargs['hue'],
            value_name=kwargs['y'])
      .rename(columns={index: kwargs['x']}))

sns.lineplot(data=df, **kwargs)
plt.savefig(args.output)
