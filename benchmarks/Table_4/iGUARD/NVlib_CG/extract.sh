#!/bin/bash
PREFIX=$1
RUN=$2

# grid_sync
benchmark="grid_sync"
caught=0;
for run in `seq 1 1 $RUN`; do
	races=$(grep -A1 "Race" "${PREFIX}${run}_${benchmark}.raw")
	races=$(echo $races | grep -oE "Missing [a-z]+fence")
	# Races are caused by missing fence
	for i in $races; do
		caught=1;
	done
done

echo ${benchmark} ${caught}
