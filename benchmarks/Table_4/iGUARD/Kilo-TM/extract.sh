#!/bin/bash
PREFIX=$1
RUN=$2

# interac
benchmark="interac"
for i in $(seq 1 1 4); do
	caught[$i]=0;
done
for run in `seq 1 1 $RUN`; do
	races=$(grep -A1 "Race" "${PREFIX}${run}_${benchmark}.raw")
	races=$(echo $races | grep -oE "Line [0-9]+")
	races=$(echo $races | grep -oE "[0-9]+")

	for i in $races; do
		if [ $i == "103" ]; then
			caught[0]=1;
		elif [ $i == "104" ]; then
			caught[1]=1;
		elif [ $i == "109" ]; then
			caught[2]=1;
		elif [ $i == "172" ]; then
			caught[2]=1;
		elif [ $i == "110" ]; then
			caught[3]=1;
		elif [ $i == "115" ]; then
			caught[3]=1;
		elif [ $i == "172" ]; then
			caught[3]=1;
		fi
	done
done

total=0
for i in ${caught[@]}; do
	total=$(awk "BEGIN {print $total + $i}");
done

echo ${benchmark} ${total}

# hashtable
benchmark="hashtable"
for i in ${!caught[@]}; do
	caught[$i]=0;
done
for run in `seq 1 1 $RUN`; do
	races=$(grep -A1 "Race" "${PREFIX}${run}_${benchmark}.raw")
	races=$(echo $races | grep -oE "Line [0-9]+")
	races=$(echo $races | grep -oE "[0-9]+")

	for i in $races; do
		if [ $i == "172" ]; then
			caught[0]=1;
		elif [ $i == "236" ]; then
			caught[0]=1;
		elif [ $i == "233" ]; then
			caught[1]=1;
		elif [ $i == "234" ]; then
			caught[1]=1;
		fi
	done
done

total=0
for i in ${caught[@]}; do
	total=$(awk "BEGIN {print $total + $i}");
done

echo ${benchmark} ${total}

