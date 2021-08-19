#!/bin/bash
PREFIX=$1
RUN=$2

# mis
benchmark="mis"
for i in $(seq 1 1 3); do
	caught[$i]=0;
done

for run in `seq 1 1 $RUN`; do
	races=$(grep -A1 "Race" "${PREFIX}${run}_${benchmark}.raw")
	races=$(echo $races | grep -oE "Line [0-9]+")
	races=$(echo $races | grep -oE "[0-9]+")

	for i in $races; do
		if [ $i == "89" ]; then
			caught[0]=1;
		elif [ $i == "101" ]; then
			caught[0]=1;
		elif [ $i == "133" ]; then
			caught[1]=1;
		elif [ $i == "147" ]; then
			caught[1]=1;
		fi
	done
done

total=0
for i in ${caught[@]}; do
	total=$(awk "BEGIN {print $total + $i}");
done

echo ${benchmark} ${total}

# cc
benchmark="cc"
for i in ${!caught[@]}; do
	caught[$i]=0;
done

for run in `seq 1 1 $RUN`; do
	races=$(grep -A1 "Race" "${PREFIX}${run}_${benchmark}.raw")
	races=$(echo $races | grep -oE "Line [0-9]+")
	races=$(echo $races | grep -oE "[0-9]+")

	for i in $races; do
		if [ $i == "257" ]; then
			caught[0]=1;
		elif [ $i == "343" ]; then
			caught[1]=1;
		elif [ $i == "346" ]; then
			caught[1]=1;
		elif [ $i == "311" ]; then
			caught[2]=1;
		elif [ $i == "312" ]; then
			caught[2]=1;
		elif [ $i == "321" ]; then
			caught[2]=1;
		fi
	done
done

total=0
for i in ${caught[@]}; do
	total=$(awk "BEGIN {print $total + $i}");
done

echo ${benchmark} ${total}

