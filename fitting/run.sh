#!/bin/bash

export PYTHONLOGLEVEL=info

root=`git rev-parse --show-toplevel`
pop=10000000
state=mh
tr_days=7
te_days=30

raw=`mktemp`  ; $root/data/covid19india/get.sh -p $pop -s $state > $raw
init=`mktemp` ; head --lines=2 $raw | cut --delimiter=',' --fields=2- > $init
train=`mktemp`; head --lines=-$tr_days $raw > $train

python estimate.py --population $pop < $train | \
    python project.py --population $pop --initial $initial --outlook $te_days |
    python visualize.py --output fit.png

rm $raw $init $train
