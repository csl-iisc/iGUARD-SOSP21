#!/bin/bash
PREFIX=$1
RUN=$2

# interac
benchmark="interac"
for i in $(seq 1 1 4); do
	caught[$i]=0;
done
for run in `seq 1 1 $RUN`; do
	races=$(grep -oE "HAZARD! me [0-9]+" "${PREFIX}${run}_${benchmark}.raw")
	races=$(echo $races | grep -oE "[0-9]+")

	for i in $races; do
		if [ $i == "88" ]; then
			caught[0]=1;
		elif [ $i == "81" ]; then
			caught[1]=1;
		elif [ $i == "83" ]; then
			caught[2]=1;
		elif [ $i == "84" ]; then
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
	races=$(grep -oE "HAZARD! me [0-9]+" "${PREFIX}${run}_${benchmark}.raw")
	races=$(echo $races | grep -oE "[0-9]+")

	for i in $races; do
		if [ $i == "19" ]; then
			caught[0]=1;
		elif [ $i == "25" ]; then
			caught[0]=1;
		elif [ $i == "23" ]; then
			caught[1]=1;
		elif [ $i == "24" ]; then
			caught[1]=1;
		fi
	done
done

total=0
for i in ${caught[@]}; do
	total=$(awk "BEGIN {print $total + $i}");
done

echo ${benchmark} ${total}

