#!/bin/bash
PREFIX=$1

# grid_sync
benchmark="grid_sync"
caught[0]=0;
races=$(grep -A1 "Race" "${PREFIX}${benchmark}.raw" | grep -oE "Line [0-9]+" | grep -oE "[0-9]+")
for i in $races; do
	if [ $i == "168" ]; then
		caught[0]=1;
	elif [ $i == "215" ]; then
		caught[0]=1;
	elif [ $i == "222" ]; then
		caught[0]=1;
	elif [ $i == "266" ]; then
		caught[0]=1;
	fi
done

total=0
for i in ${caught[@]}; do
	total=$(awk "BEGIN {print $total + $i}");
done

echo ${benchmark} ${total}
