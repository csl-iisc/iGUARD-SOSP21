#!/bin/bash
PREFIX=$1

# shoc_bfs
benchmark="shoc_bfs"
for i in $(seq 1 1 2); do
	caught[$i]=0;
done

for run in `seq 1 1 $RUN`; do
	races=$(grep -A1 "Race" "${PREFIX}${run}_${benchmark}.raw")
	races=$(echo $races | grep -oE "Line [0-9]+")
	races=$(echo $races | grep -oE "[0-9]+")

	for i in $races; do
		if [ $i == "63" ]; then
			caught[0]=1;
		elif [ $i == "70" ]; then
			caught[0]=1;
		elif [ $i == "72" ]; then
			caught[0]=1;
		elif [ $i == "73" ]; then
			caught[1]=1;
		fi
	done
done

total=0
for i in ${caught[@]}; do
	total=$(awk "BEGIN {print $total + $i}");
done

echo ${benchmark} ${total}
