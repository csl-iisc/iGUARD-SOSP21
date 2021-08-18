#!/bin/bash
PREFIX=$1

# louvain
benchmark="louvain"
for i in $(seq 1 1 3); do
	caught[$i]=0;
done
races=$(grep -A1 "Race" "${PREFIX}${benchmark}.raw")
races=$(echo $races | grep -oE "Line [0-9]+")
races=$(echo $races | grep -oE "[0-9]+")

for i in $races; do
	if [ $i == "206" ]; then
		caught[0]=1;
	elif [ $i == "251" ]; then
		caught[0]=1;
	elif [ $i == "92" ]; then
		caught[1]=1;
	elif [ $i == "82" ]; then
		caught[1]=1;
	elif [ $i == "463" ]; then
		caught[1]=1;
	elif [ $i == "48" ]; then
		caught[2]=1;
	fi
done

total=0
for i in ${caught[@]}; do
	total=$(awk "BEGIN {print $total + $i}");
done

echo ${benchmark} ${total}

# bc
benchmark="bc"
for i in ${!caught[@]}; do
	caught[$i]=0;
done
races=$(grep -A1 "Race" "${PREFIX}${benchmark}.raw")
races=$(echo $races | grep -oE "Line [0-9]+")
races=$(echo $races | grep -oE "[0-9]+")

for i in $races; do
	if [ $i == "177" ]; then
		caught[0]=1;
	elif [ $i == "278" ]; then
		caught[0]=1;
	fi
done

total=0
for i in ${caught[@]}; do
	total=$(awk "BEGIN {print $total + $i}");
done

echo ${benchmark} ${total}

# pr_nibble
benchmark="pr_nibble"
for i in ${!caught[@]}; do
	caught[$i]=0;
done
races=$(grep -A1 "Race" "${PREFIX}${benchmark}.raw")
races=$(echo $races | grep -oE "Line [0-9]+")
races=$(echo $races | grep -oE "[0-9]+")

for i in $races; do
	if [ $i == "206" ]; then
		caught[0]=1;
	elif [ $i == "251" ]; then
		caught[0]=1;
	fi
done

total=0
for i in ${caught[@]}; do
	total=$(awk "BEGIN {print $total + $i}");
done

echo ${benchmark} ${total}

# sm
benchmark="sm"
for i in ${!caught[@]}; do
	caught[$i]=0;
done
races=$(grep -A1 "Race" "${PREFIX}${benchmark}.raw")
races=$(echo $races | grep -oE "Line [0-9]+")
races=$(echo $races | grep -oE "[0-9]+")

for i in $races; do
	if [ $i == "111" ]; then
		caught[0]=1;
	elif [ $i == "82" ]; then
		caught[0]=1;
	fi
done

total=0
for i in ${caught[@]}; do
	total=$(awk "BEGIN {print $total + $i}");
done

echo ${benchmark} ${total}

# color
benchmark="color"
for i in ${!caught[@]}; do
	caught[$i]=0;
done
races=$(grep -A1 "Race" "${PREFIX}${benchmark}.raw")
races=$(echo $races | grep -oE "Line [0-9]+")
races=$(echo $races | grep -oE "[0-9]+")

for i in $races; do
	if [ $i == "129" ]; then
		caught[0]=1;
	elif [ $i == "132" ]; then
		caught[1]=1;
	elif [ $i == "112" ]; then
		caught[0]=1;
		caught[1]=1;
	elif [ $i == "107" ]; then
		caught[0]=1;
	elif [ $i == "117" ]; then
		caught[1]=1;
	fi
done

total=0
for i in ${caught[@]}; do
	total=$(awk "BEGIN {print $total + $i}");
done

echo ${benchmark} ${total}

