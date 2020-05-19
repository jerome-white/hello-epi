#!/bin/bash

export PYTHONLOGLEVEL=info

root=`git rev-parse --show-toplevel`
pop=10000000
state=mh
tr_days=7
pr_days=180

path=results/`TZ=Asia/Kolkata date +%j-%d%b-%I%M | tr [:lower:] [:upper:]`
mkdir --parents $path

#
# Get the data
#
$root/data/covid19india/get.sh -p $pop -s $state > $path/raw.csv

#
#
#
python $root/data/covid19india/smooth.py --window 3 < $path/raw.csv | \
    head --lines=-$tr_days | \
    python estimate.py > $path/params.csv

#
#
#
init=`mktemp`
head --lines=2 $path/raw.csv | cut --delimiter=',' --fields=2- > $init
days=`tail --lines=+2 $path/raw.csv | \
	   wc --lines | \
	   cut --delimiter=' ' --fields=1`
python project.py --initial $init --outlook `expr $days + $pr_days` < \
       $path/params.csv > \
       $path/projection.csv
rm $init

gzip $path/params.csv
