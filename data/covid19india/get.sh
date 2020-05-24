#!/bin/bash

url="https://api.covid19india.org/csv/latest/state_wise_daily.csv"
state=mh
population=10000000

while getopts "p:s:h" OPTION; do
    case $OPTION in
	p) population=$OPTARG ;;
	s) state=`tr [:upper:] [:lower:] <<< $OPTARG` ;;
        h)
	    cat <<EOF
Usage: $0 [options]
 -p Population (default $population)
 -s Two-letter abbreviation of state (default $state)
EOF
            exit
            ;;
        *) exit 1 ;;
    esac
done

here=$(dirname $(realpath $0))
wget --quiet --output-document=- $url | \
    python $here/get.py | \
    python $here/extract.py --state $state
