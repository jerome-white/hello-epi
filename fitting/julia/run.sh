#!/bin/bash

ROOT=`git rev-parse --show-toplevel`
DATA=$ROOT/data
RESULTS=$ROOT/results
OUTPUT=$RESULTS/`TZ=Asia/Kolkata date +%j-%d%b-%H%M | tr [:lower:] [:upper:]`

export PYTHONLOGLEVEL=debug
export PYTHONPATH=$ROOT
export JULIA_NUM_THREADS=`nproc`

JULIA_VIRTUAL_MODEL=modeler.jl

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
smooth=
lead_time=20
validation_days=5
testing_days=21
viz_days=(
    7
    $testing_days
)
ci=(
    0.5
    0.25
    0.0
)
julia_model=seird.jl

draws=10000
samples=`expr $JULIA_NUM_THREADS \* 2000`

#
#
#
if [ -d $RESULTS ]; then
    python $ROOT/scripts/clean-results.py --results $RESULTS
fi

mkdir --parents $OUTPUT
echo "[ `date` RESULTS ] $OUTPUT"

cat <<EOF > $OUTPUT/README
validation days: $validation_days
smoothing: $smooth
disaggregate: $disaggregate
EOF

rm --force $JULIA_VIRTUAL_MODEL
ln --symbolic $julia_model $JULIA_VIRTUAL_MODEL
cp $julia_model $OUTPUT

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

python $DATA/covid19india/state-wise-daily.py \
    | python $DATA/covid19india/clean.py \
    | python $DATA/general/make-sird.py ${args[@]} \
	     > $OUTPUT/raw.csv \
    || exit

if [ $disaggregate ]; then
    python $DATA/general/disaggregate.py \
	   < $OUTPUT/raw.csv \
	   > $OUTPUT/cooked.csv
else
    ln --symbolic --relative $OUTPUT/raw.csv $OUTPUT/cooked.csv
fi

#
#
#
if [ $smooth ]; then
    python $DATA/covid19india/smooth.py --window $smooth \
	| python $DATA/general/make-sird.py ${args[@]}
else
    tee
fi < $OUTPUT/cooked.csv \
    | head --lines=-$validation_days \
	   > $OUTPUT/training.csv

#
#
#
trace_opt="--trace $OUTPUT/chains.jls"

echo "[ `date` RESULTS ] Estimate"
julia estimate.jl $trace_opt \
      --draws $draws \
      --population $population \
      --lead $lead_time \
      < $OUTPUT/training.csv \
    || exit

#
#
#
echo "[ `date` RESULTS ] Evaluate"
cat <<EOF | parallel --will-cite --line-buffer
julia model-explorer.jl $trace_opt --output $OUTPUT/trace.png
julia sample-post.jl $trace_opt --samples $samples > $OUTPUT/params.csv
EOF

#
#
#
echo "[ `date` RESULTS ] Project"
offset=`python $DATA/general/days-between.py \
      --source $OUTPUT/raw.csv \
      --target $OUTPUT/training.csv`
julia project.jl \
      --population $population \
      --offset $offset \
      --forward $testing_days \
      --lead $lead_time \
      --observations $OUTPUT/training.csv \
      < $OUTPUT/params.csv \
      > $OUTPUT/projection.csv

#
#
#
tmp=`mktemp`
intervals="--ci `sed -e's/ / --ci /g' <<< ${ci[@]}`"

for i in ${viz_days[@]}; do
    fname=`printf "fit-%03d.png" $i`
    cat <<EOF
python $ROOT/visualization/projection.py $intervals \
       --ground-truth $OUTPUT/cooked.csv \
       --validation-days $validation_days \
       --testing-days $i \
       --output $OUTPUT/$fname \
       < $OUTPUT/projection.csv
EOF
done > $tmp

if [ $disaggregate ]; then
    cat <<EOF >> $tmp
python $DATA/general/accumulate.py \
       < $OUTPUT/projection.csv \
    | python $ROOT/visualization/projection.py \
	     --ground-truth $OUTPUT/raw.csv \
	     --testing-days $validation_days \
	     --project $testing_days \
	     --output $OUTPUT/cummulative.png
EOF
fi

parallel --will-cite --line-buffer :::: $tmp
rm $tmp
