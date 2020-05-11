#!/bin/bash

url="https://api.covid19india.org/csv/latest/state_wise_daily.csv"
state=mh
pop=10000000

wget --quiet --output-document=- $url | \
    python get.py | \
    python extract.py --state $state | \
    python add-susceptible.py --population $pop --with-variance
