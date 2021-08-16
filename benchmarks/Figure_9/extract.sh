#!/bin/bash
PREFIX_NODET1=$1
PREFIX_NODET2=$2
PREFIX_DET1=$3
PREFIX_DET2=$4
BENCHMARKS=$5
RUNS=$6
declare -A nodet1_res
declare -A nodet2_res
declare -A det1_res
declare -A det2_res

for runs in `seq 1 1 ${RUNS}`; do
	for file in ${PREFIX_NODET1}${runs}*; do
		benchmark=${file#"${PREFIX_NODET1}${runs}_"}
		benchmark=${benchmark%".raw"}
		[ -z "${nodet1_res[$benchmark]}" ] && nodet1_res[$benchmark]=0
		nodet1_res[$benchmark]=$(awk "BEGIN {print ${nodet1_res[$benchmark]}+$(grep "^runtime" $file | grep -oE "[0-9]+\.[0-9]+")}")
	done
done

for runs in `seq 1 1 ${RUNS}`; do
	for file in ${PREFIX_NODET2}${runs}*; do
		benchmark=${file#"${PREFIX_NODET2}${runs}_"}
		benchmark=${benchmark%".raw"}
		[ -z "${nodet_res2[$benchmark]}" ] && nodet_res2[$benchmark]=0
		nodet2_res[$benchmark]=$(awk "BEGIN {print ${nodet2_res[$benchmark]}+$(grep "^runtime" $file | grep -oE "[0-9]+\.[0-9]+")}")
	done
done


for runs in `seq 1 1 ${RUNS}`; do
	for file in ${PREFIX_DET1}${runs}*; do
		benchmark=${file#"${PREFIX_DET1}${runs}_"}
		benchmark=${benchmark%".raw"}
		[ -z "${det1_res[$benchmark]}" ] && det1_res[$benchmark]=0
		det1_res[$benchmark]=$(awk "BEGIN {print ${det1_res[$benchmark]}+$(grep "^runtime" $file | grep -oE "[0-9]+\.[0-9]+")}")
	done
done


for runs in `seq 1 1 ${RUNS}`; do
	for file in ${PREFIX_DET2}${runs}*; do
		benchmark=${file#"${PREFIX_DET2}${runs}_"}
		benchmark=${benchmark%".raw"}
		[ -z "${det2_res[$benchmark]}" ] && det2_res[$benchmark]=0
		det2_res[$benchmark]=$(awk "BEGIN {print ${det2_res[$benchmark]}+$(grep "^runtime" $file | grep -oE "[0-9]+\.[0-9]+")}")
	done
done


: '''
for i in ${!nodet_res[@]}; do
	echo $i
	nodet_res[$i]=$(awk "BEGIN {print ${nodet_res[$i]}/${RUNS}}")
	echo ${nodet_res[$i]}
done

for i in ${!det1_res[@]}; do
	echo $i
	det1_res[$i]=$(awk "BEGIN {print ${det1_res[$i]}/${RUNS}}")
	echo ${det1_res[$i]}
done

for i in ${!det2_res[@]}; do
	echo $i
	det2_res[$i]=$(awk "BEGIN {print ${det2_res[$i]}/${RUNS}}")
	echo ${det2_res[$i]}
done
'''

printf "Normalised performance results\n"
printf "Benchmark\tiGUARD\tBarracuda\n"
for i in ${BENCHMARKS}; do
	#echo $i ${det1_res[$i]} ${nodet1_res[$i]}
	iguard=$(awk "BEGIN {print ${det1_res[$i]}/${nodet1_res[$i]}}")
	[ -z "${det2_res[$benchmark]}" ] && barracuda="-" || barracuda=$(awk "BEGIN {print ${det2_res[$i]}/${nodet2_res[$i]}}")
	#printf "%s\t%f\t%f\n" $i $without_opt $with_opt
	[ -z "${det2_res[$benchmark]}" ] && printf "%s\t%f\t-\n" $i $iguard || printf "%s\t%f\t%f\n" $i $iguard $barracuda
done
