#!/bin/bash

export PYTHONLOGLEVEL=info

root=`git rev-parse --show-toplevel`
places=(
    maharashtra:pune:13671091
    maharashtra:mumbai:2851561
)
smooth=3
te_days=5
pr_days=365
pr_viz_days=$te_days

path=results/`TZ=Asia/Kolkata date +%j-%d%b-%H%M | tr [:lower:] [:upper:]`
mkdir --parents $path
echo "[ `date` RESULTS ] $path"

#
#
#
cat <<EOF > $path/README
training days: $te_days
smoothing: $smooth
EOF

for i in ${places[@]}; do
    echo "location: $i"
done >> $path/README

#
# Get the data
#
for i in ${places[@]}; do
    opts=( `sed -e's/:/ /g' <<< $i` )
    args=(
	--state ${opts[0]}
	--district ${opts[1]}
	--population ${opts[2]}
	${args[@]}
    )
done

$root/data/covid19india/get-data.sh |
    python make-sird.py ${args[@]} > $path/raw.csv

#
#
#
rm --recursive --force $HOME/.theano/compiledir*
python $root/data/covid19india/smooth.py --window $smooth < $path/raw.csv | \
    head --lines=-$te_days | \
    python estimate.py > $path/params.csv || exit

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

for i in $pr_days $pr_viz_days; do
    fname=`printf "fit-%03d.png" $i`
    cat <<EOF
python visualize.py \
       --ground-truth $path/raw.csv \
       --testing-days $te_days \
       --project $i \
       --output $path/$fname < \
       $path/projection.csv
EOF
done | parallel --will-cite --line-buffer
