#!/bin/bash
PREFIX_DET1=$1
PREFIX_DET2=$2
BENCHMARKS=$3
NO_RACE_BENCH=$4

declare -A iGUARD_races
declare -A BARR_races

# Racey iGUARD
for benchmark in ${BENCHMARKS}; do
	file="iGUARD/results.out"
	if [ -f $file ]; then
		ant=$(grep "^$benchmark" $file | grep -oE " [0-9]+" | grep -oE "[0-9]+")
		if [ -z "$ant" ]; then
			iGUARD_races[$benchmark]="-"
		else
			iGUARD_races[$benchmark]="$ant"
		fi
	else
		iGUARD_races[$benchmark]="-"
	fi
done

# Racey Barracuda
for benchmark in ${BENCHMARKS}; do
	file="Barracuda/results.out"
	if [ -f $file ]; then
		ant=$(grep "$benchmark" $file | grep -oE "[0-9]+")
		if [ -z "$ant" ]; then
			BARR_races[$benchmark]="-"
		else
			BARR_races[$benchmark]="$ant"
		fi
	else
		BARR_races[$benchmark]="-"
	fi
done

# Race-free iGUARD
for benchmark in ${NO_RACE_BENCH}; do
	file="${PREFIX_DET1}1_${benchmark}.raw"
	if [ -f $file ]; then
		ant=$(grep "Race" $file)
		if [ -z "$ant" ]; then
			iGUARD_races[$benchmark]="0"
		else
			iGUARD_races[$benchmark]=${#ant[@]}
		fi
	else
		iGUARD_races[$benchmark]="-"
	fi
done

# Race-free Barracuda
for benchmark in ${NO_RACE_BENCH}; do
	file="${PREFIX_DET2}1_${benchmark}.raw"
	if [ -f $file ]; then
		ant=$(grep "Race" $file)
		if [ -z "$ant" ]; then
			BARR_races[$benchmark]="0"
		else
			BARR_races[$benchmark]=${#ant[@]}
		fi
	else
		BARR_races[$benchmark]="-"
	fi
done

printf "Races caught\n"
printf "Benchmark\tBarracuda\tiGUARD\n"
for i in $BENCHMARKS; do
	printf "%s\t%s\t%s\n" $i ${BARR_races[$i]} ${iGUARD_races[$i]} 	
done

for i in $NO_RACE_BENCH; do
	printf "%s\t%s\t%s\n" $i ${BARR_races[$i]} ${iGUARD_races[$i]} 
done
