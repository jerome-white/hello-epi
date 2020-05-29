#!/bin/bash

export PYTHONLOGLEVEL=info

ROOT=`git rev-parse --show-toplevel`
DATA=$ROOT/data/covid19india
RESULTS=results
OUTPUT=$RESULTS/`TZ=Asia/Kolkata date +%j-%d%b-%H%M | tr [:lower:] [:upper:]`

#
#
#
places=(
    # maharashtra:pune:13671091  # FB (district)
    # maharashtra:pune:312445    # Wikipedia (city)
    # maharashtra:pune:5057709   # Wikipedia (greater)
    # maharashtra:mumbai:2851561 # FB (district)
)
if [ ${#places[@]} -eq 0 ]; then
    exit 1
fi

pfrac=0.2
smooth=7
te_days=5
pr_days=365
pr_viz_days=$te_days

#
#
#
# python clean.py --results $RESULTS

mkdir --parents $OUTPUT
echo "[ `date` RESULTS ] $OUTPUT"

cat <<EOF > $OUTPUT/README
training days: $te_days
smoothing: $smooth
EOF

for i in ${places[@]}; do
    echo "location: $i"
done >> $OUTPUT/README

#
# Get the data
#
test $pfrac || pfrac=1
for i in ${places[@]}; do
    opts=( `sed -e's/:/ /g' <<< $i` )
    args=(
	--state ${opts[0]}
	--district ${opts[1]}
	--population $(printf "%.0f" `bc --mathlib <<< "${opts[2]} * $pfrac"`)
	${args[@]}
    )
done

python $DATA/state-wise-daily.py | \
    python $DATA/clean.py --disaggregate | \
    python make-sird.py ${args[@]} > \
	   $OUTPUT/raw.csv || exit

#
#
#
rm --recursive --force $HOME/.theano/compiledir*
if [ $smooth ]; then
    python $DATA/smooth.py --window $smooth
else
    tee
fi < $OUTPUT/raw.csv | \
    head --lines=-$te_days | \
    python estimate.py --trace $OUTPUT/trace.png > \
	   $OUTPUT/params.csv || exit

#
#
#
days=`tail --lines=+2 $OUTPUT/raw.csv | \
	   wc --lines | \
	   cut --delimiter=' ' --fields=1`
python project.py --data $OUTPUT/raw.csv --outlook `expr $days + $pr_days` < \
       $OUTPUT/params.csv > \
       $OUTPUT/projection.csv

for i in $pr_days $pr_viz_days; do
    fname=`printf "fit-%03d.png" $i`
    cat <<EOF
python visualize.py \
       --ground-truth $OUTPUT/raw.csv \
       --testing-days $te_days \
       --project $i \
       --output $OUTPUT/$fname < \
       $OUTPUT/projection.csv
EOF
done | parallel --will-cite --line-buffer
