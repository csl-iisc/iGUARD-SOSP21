#!/bin/bash
PREFIX=$1

# matrix-mult
benchmark="matrix-mult"
for i in $(seq 1 1 7); do
	caught[$i]=0;
done
races=$(grep -A1 "Race" "${PREFIX}${benchmark}.raw")
races=$(echo $races | grep -oE "Line [0-9]+")
races=$(echo $races | grep -oE "[0-9]+")

for i in $races; do
	if [ $i == "104" ]; then
		caught[0]=1;
	elif [ $i == "337" ]; then
		caught[1]=1;
	elif [ $i == "97" ]; then
		caught[2]=1;
	elif [ $i == "127" ]; then
		caught[3]=1;
	fi
done

total=0
for i in ${caught[@]}; do
	total=$(awk "BEGIN {print $total + $i}");
done

echo ${benchmark} ${total}

# 1dconv
benchmark="1dconv"
for i in ${!caught[@]}; do
	caught[$i]=0;
done
races=$(grep -A1 "Race" "${PREFIX}${benchmark}.raw")
races=$(echo $races | grep -oE "Line [0-9]+")
races=$(echo $races | grep -oE "[0-9]+")

for i in $races; do
	if [ $i == "121" ]; then
		caught[0]=1;
	fi
done

total=0
for i in ${caught[@]}; do
	total=$(awk "BEGIN {print $total + $i}");
done

echo ${benchmark} ${total}

# graph-con
benchmark="graph-con"
for i in ${!caught[@]}; do
	caught[$i]=0;
done
races=$(grep -A1 "Race" "${PREFIX}${benchmark}1.raw")
races=$(echo $races | grep -oE "Kernel [a-zA-Z]+")

for i in $races; do
	if [ $i == "initKernel" ]; then
		caught[0]=1;
	fi
done

races=$(grep -A1 "Race" "${PREFIX}${benchmark}2.raw")
races=$(echo $races | grep -oE "Kernel [a-zA-Z]+")
for i in $races; do
	if [ $i == "linkKernel" ]; then
		caught[1]=1;
	fi
done

races=$(grep -A1 "Race" "${PREFIX}${benchmark}3.raw")
races=$(echo $races | grep -oE "Kernel [a-zA-Z]+")

for i in $races; do
	if [ $i == "compressKernel" ]; then
		caught[2]=1;
	fi
done

races=$(grep -A1 "Race" "${PREFIX}${benchmark}4.raw")
races=$(echo $races | grep -oE "Kernel [a-zA-Z]+")
for i in $races; do
	if [ $i == "linkKernel" ]; then
		caught[3]=1;
	elif [ $i == "compressKernel" ]; then
		caught[4]=1;
	fi
done

total=0
for i in ${caught[@]}; do
	total=$(awk "BEGIN {print $total + $i}");
done

echo ${benchmark} ${total}

# reduction
benchmark="reduction"
for i in ${!caught[@]}; do
	caught[$i]=0;
done
races=$(grep -A1 "Race" "${PREFIX}${benchmark}.raw")
races=$(echo $races | grep -oE "Line [0-9]+")
races=$(echo $races | grep -oE "[0-9]+")

for i in $races; do
	if [ $i == "77" ]; then
		caught[0]=1;
	elif [ $i == "95" ]; then
		caught[0]=1;
	elif [ $i == "99" ]; then
		caught[1]=1;
	elif [ $i == "103" ]; then
		caught[2]=1;
	elif [ $i == "107" ]; then
		caught[3]=1;
	elif [ $i == "111" ]; then
		caught[4]=1;
	elif [ $i == "115" ]; then
		caught[5]=1;
	elif [ $i == "201" ]; then
		caught[6]=1;
	fi
done

total=0
for i in ${caught[@]}; do
	total=$(awk "BEGIN {print $total + $i}");
done

echo ${benchmark} ${total}

# rule-110
benchmark="rule-110"
for i in ${!caught[@]}; do
	caught[$i]=0;
done

races=$(grep -A1 "Race" "${PREFIX}${benchmark}1.raw")
races=$(echo $races | grep -oE "Line [0-9]+")
races=$(echo $races | grep -oE "[0-9]+")
for i in $races; do
	if [ $i == "75" ]; then
		caught[0]=1;
	elif [ $i == "109" ]; then
		caught[0]=1;
	fi
done

races=$(grep -A1 "Race" "${PREFIX}${benchmark}2.raw")
races=$(echo $races | grep -oE "Line [0-9]+")
races=$(echo $races | grep -oE "[0-9]+")
for i in $races; do
	if [ $i == "77" ]; then
		caught[1]=1;
	elif [ $i == "97" ]; then
		caught[1]=1;
	fi
done


total=0
for i in ${caught[@]}; do
	total=$(awk "BEGIN {print $total + $i}");
done

echo ${benchmark} ${total}

# uts
benchmark="uts"
for i in ${!caught[@]}; do
	caught[$i]=0;
done

races=$(grep -A1 "Race" "${PREFIX}${benchmark}1.raw")
races=$(echo $races | grep -oE "Line [0-9]+")
races=$(echo $races | grep -oE "[0-9]+")
for i in $races; do
	if [ $i == "97" ]; then
		caught[0]=1;
	elif [ $i == "337" ]; then
		caught[1]=1;
	fi
done

races=$(grep -A1 "Race" "${PREFIX}${benchmark}2.raw")
races=$(echo $races | grep -oE "Line [0-9]+")
races=$(echo $races | grep -oE "[0-9]+")
for i in $races; do
	if [ $i == "87" ]; then
		caught[2]=1;
	elif [ $i == "169" ]; then
		caught[3]=1;
	elif [ $i == "237" ]; then
		caught[4]=1;
	elif [ $i == "172" ]; then
		caught[5]=1;
	fi
done


total=0
for i in ${caught[@]}; do
	total=$(awk "BEGIN {print $total + $i}");
done

echo ${benchmark} ${total}

# graph-color
benchmark="graph-color"
for i in ${!caught[@]}; do
	caught[$i]=0;
done

races=$(grep -A1 "Race" "${PREFIX}${benchmark}1.raw")
races=$(echo $races | grep -oE "Kernel [a-zA-Z]+")
for i in $races; do
	if [ $i == "assignColorsKernel" ]; then
		caught[0]=1;
	elif [ $i == "detectConflictsKernel" ]; then
		caught[1]=1;
	elif [ $i == "forbidColorsKernel" ]; then
		caught[2]=1;
	fi
done

races=$(grep -A1 "Race" "${PREFIX}${benchmark}2.raw")
races=$(echo $races | grep -oE "Kernel [a-zA-Z]+")
for i in $races; do
	if [ $i == "assignColorsKernel" ]; then
		caught[3]=1;
	elif [ $i == "detectConflictsKernel" ]; then
		caught[4]=1;
	elif [ $i == "forbidColorsKernel" ]; then
		caught[5]=1;
	fi
done

total=0
for i in ${caught[@]}; do
	total=$(awk "BEGIN {print $total + $i}");
done

echo ${benchmark} ${total}
