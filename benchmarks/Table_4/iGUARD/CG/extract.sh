#!/bin/bash
PREFIX=$1

# conjugGMB
benchmark="conjugGMB"
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

# reduceMB
benchmark="reduceMB"
caught[0]=0;
races=$(grep -A1 "Race" "${PREFIX}${benchmark}.raw" | grep -oE "Line [0-9]+" | grep -oE "[0-9]+")
for i in $races; do
	if [ $i == "116" ]; then
		caught[0]=1;
	elif [ $i == "122" ]; then
		caught[0]=1;
	fi
done

total=0
for i in ${caught[@]}; do
	total=$(awk "BEGIN {print $total + $i}");
done

echo ${benchmark} ${total}


# warpAA
benchmark="warpAA"
caught[0]=0;
races=$(grep -A1 "Race" "${PREFIX}${benchmark}.raw" | grep -oE "Line [0-9]+" | grep -oE "[0-9]+")
for i in $races; do
	# Should not trigger a race, so any race is counted
	caught[0]=1;
done

total=0
for i in ${caught[@]}; do
	total=$(awk "BEGIN {print $total + $i}");
done

echo ${benchmark} ${total}
