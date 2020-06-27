#!/bin/bash

export PYTHONLOGLEVEL=debug

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
    # maharashtra:mumbai:142578  # 2% FB (district)
)
if [ ${#places[@]} -eq 0 ]; then
    echo "Must specify at least one location" 1>&2
    exit 1
fi

disaggregate=
smooth=7
te_days=2
pr_days=21
pr_viz_days=(
    7
    $pr_days
)

draws=4000
samples=`bc -l <<< "2000 / $draws"`

#
#
#
if [ -d $RESULTS ]; then
    python $ROOT/scripts/clean-results.py --results $RESULTS
fi

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
if [ $smooth ]; then
    python $DATA/covid19india/smooth.py --window $smooth | \
	python $DATA/general/make-sird.py ${args[@]}
else
    tee
fi < $OUTPUT/cooked.csv | \
    head --lines=-$te_days > $OUTPUT/training.csv

trace_opt="--trace $OUTPUT/chains.jls"

echo "[ `date` RESULTS ] Estimate"
julia estimate.jl $trace_opt \
      --population $population \
      --draws $draws \
      < $OUTPUT/training.csv \
    || exit

echo "[ `date` RESULTS ] Evaluate"
cat <<EOF | parallel --will-cite --line-buffer
julia model-explorer.jl $trace_opt --output $OUTPUT/trace.png
julia sample-post.jl $trace_opt --samples $samples > $OUTPUT/params.csv
EOF

echo "[ `date` RESULTS ] Project"
offset=`python $DATA/general/days-between.py \
      --source $OUTPUT/raw.csv \
      --target $OUTPUT/training.csv`
julia project.jl \
      --population $population \
      --offset $offset \
      --forward $pr_days \
      --observations $OUTPUT/training.csv \
      < $OUTPUT/params.csv \
      > $OUTPUT/projection.csv

#
#
#
tmp=`mktemp`
for i in ${pr_viz_days[@]}; do
    fname=`printf "fit-%03d.png" $i`
    cat <<EOF
python $ROOT/visualization/projection.py \
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
    python $ROOT/visualization/projection.py \
	   --ground-truth $OUTPUT/raw.csv \
	   --testing-days $te_days \
	   --project $pr_days \
	   --output $OUTPUT/cummulative.png
EOF
fi

parallel --will-cite --line-buffer :::: $tmp
rm $tmp
