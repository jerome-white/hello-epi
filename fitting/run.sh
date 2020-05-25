#!/bin/bash

export PYTHONLOGLEVEL=info

root=`git rev-parse --show-toplevel`
tr_days=7
pr_days=180
pr_viz_days=10

path=results/`TZ=Asia/Kolkata date +%j-%d%b-%H%M | tr [:lower:] [:upper:]`
mkdir --parents $path
echo "[ `date` RESULTS ] $path"

#
# Get the data
#
$root/data/covid19india/state-wise-daily.py |
    python mkdata.py \
	   --state maharashtra \
	   --district pune \
	   --population 100000 > \
	   $path/raw.csv

#
#
#
rm --recursive --force $HOME/.theano/compiledir*
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

python visualize.py \
       --ground-truth $path/raw.csv \
       --project $pr_viz_days \
       --output $path/fit.png < \
       $path/projection.csv
