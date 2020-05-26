#!/bin/bash

here=$(dirname $(realpath $0))
python $here/state-wise-daily.py | \
    python $here/clean.py
