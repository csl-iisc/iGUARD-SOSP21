#!/bin/bash
PREFIX=$1

# shoc_bfs
benchmark="shoc_bfs"
for i in $(seq 1 1 2); do
	caught[$i]=0;
done
races=$(grep -oE "HAZARD! me [0-9]+" "${PREFIX}${benchmark}.raw")
races=$(echo $races | grep -oE "[0-9]+")

for i in $races; do
	if [ $i == "10" ]; then
		caught[0]=1;
	elif [ $i == "15" ]; then
		caught[0]=1;
	elif [ $i == "16" ]; then
		caught[0]=1;
	elif [ $i == "17" ]; then
		caught[1]=1;
	fi
done

total=0
for i in ${caught[@]}; do
	total=$(awk "BEGIN {print $total + $i}");
done

echo ${benchmark} ${total}
