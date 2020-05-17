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

outlook=`expr $(wc --lines $raw | cut --delimiter=' ' --fields=1) + $te_days`

params=`mktemp`
python estimate.py --population $pop < $train > $params
python project.py \
       --population $pop \
       --initial $init \
       --outlook $outlook < $params | \
    python visualize.py --output fit.png

rm $raw $init $train $params
