#!/bin/bash

export PYTHONLOGLEVEL=info

ROOT=`git rev-parse --show-toplevel`
DATA=$ROOT/data
RESULTS=$ROOT/results
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
    echo "Must specify at least one location" 1>&2
    exit 1
fi

disaggregate=
smooth=7
te_days=5
pr_days=180
pr_viz_days=$te_days

#
#
#
# python $ROOT/scripts/clean-results.py --results $RESULTS

mkdir --parents $OUTPUT
echo "[ `date` RESULTS ] $OUTPUT"

cat <<EOF > $OUTPUT/README
training days: $te_days
smoothing: $smooth
disaggregate: $disaggregate
EOF

#
# Get the data
#

population=0
for i in ${places[@]}; do
    opts=( `sed -e's/:/ /g' <<< $i` )
    args=(
	--state ${opts[0]}
	--district ${opts[1]}
	--population ${opts[2]}
	${args[@]}
    )
    # accumulate for later
    population=`expr ${opts[2]} + $population`
done
cat <<EOF >> $OUTPUT/README
make-sird: ${args[@]}
EOF

python $DATA/covid19india/state-wise-daily.py | \
    python $DATA/covid19india/clean.py | \
    python $DATA/general/make-sird.py ${args[@]} > $OUTPUT/raw.csv || exit

if [ $disaggregate ]; then
    python $DATA/general/disaggregate.py < $OUTPUT/raw.csv > $OUTPUT/cooked.csv
else
    ln --symbolic --relative $OUTPUT/raw.csv $OUTPUT/cooked.csv
fi

#
#
#
rm --recursive --force $HOME/.theano/compiledir*
if [ $smooth ]; then
    python $DATA/covid19india/smooth.py --window $smooth | \
	python $DATA/general/make-sird.py ${args[@]}
else
    tee
fi < $OUTPUT/cooked.csv | \
    head --lines=-$te_days > $OUTPUT/training.csv

# PyMC3 has trouble with long chains. Uncomment the following line,
# and possibly play with the values, to help manage sample length.
# mcopts=--workers $(printf "%.0f" $(bc -l <<< "$(nproc) * 0.7")) --draws 1000
python estimate.py $mcopts \
       --population $population \
       --trace $OUTPUT/trace.png < \
       $OUTPUT/training.csv > \
       $OUTPUT/params.csv \
    || exit

#
#
#
days=`tail --lines=+2 $OUTPUT/cooked.csv | \
	   wc --lines | \
	   cut --delimiter=' ' --fields=1`
python project.py \
       --population $population \
       --data $OUTPUT/training.csv \
       --outlook `expr $days + $pr_days` < \
       $OUTPUT/params.csv > \
       $OUTPUT/projection.csv

#
#
#
tmp=`mktemp`
for i in $pr_days $pr_viz_days; do
    fname=`printf "fit-%03d.png" $i`
    cat <<EOF
python $ROOT/visualize/projection.py \
       --ground-truth $OUTPUT/cooked.csv \
       --testing-days $te_days \
       --project $i \
       --output $OUTPUT/$fname < \
       $OUTPUT/projection.csv
EOF
done > $tmp

if [ $disaggregate ]; then
    cat <<EOF >> $tmp
python $DATA/general/accumulate.py < $OUTPUT/projection.csv | \
    python $ROOT/visualize/projection.py \
	   --ground-truth $OUTPUT/raw.csv \
	   --testing-days $te_days \
	   --project $pr_viz_days \
	   --output $OUTPUT/cummulative.png
EOF
fi

parallel --will-cite --line-buffer :::: $tmp
rm $tmp
