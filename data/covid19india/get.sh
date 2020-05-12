#!/bin/bash

url="https://api.covid19india.org/csv/latest/state_wise_daily.csv"
state=mh
pop=10000000

wget --quiet --output-document=- $url | \
    python $here/get.py | \
    python $here/extract.py --state $state | \
    python $here/add-susceptible.py --population $population --with-variance
