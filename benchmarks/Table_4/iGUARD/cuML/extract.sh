#!/bin/bash
PREFIX=$1
RUN=$2

benchmark="prims"
for i in $(seq 1 1 3); do
	caught[$i]=0;
done
for run in `seq 1 1 $RUN`; do
	races=$(grep -A1 "Race" "${PREFIX}${run}_${benchmark}.raw")
	races=$(echo $races | grep -E "Race")
	races=$(echo $races | grep -oE "[a-z]+")

	for i in $races; do
		if [ $i == "gpufence" ]; then
			caught[0]=1;
		fi
	done
done

total=0
for i in ${caught[@]}; do
	total=$(awk "BEGIN {print $total + $i}");
done

echo ${benchmark} ${total}

