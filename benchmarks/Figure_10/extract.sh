#!/bin/bash
cd results/
PREFIX_NODET=$1
PREFIX_DET1=$2
PREFIX_DET2=$3
RUNS=$4
BENCHMARKS=$5
declare -A nodet_res
declare -A det1_res
declare -A det2_res

for runs in `seq 1 1 ${RUNS}`; do
	for file in ${PREFIX_NODET}${runs}*; do
		benchmark=${file#"${PREFIX_NODET}${runs}_"}
		benchmark=${benchmark%".raw"}
		[ -z "${nodet_res[$benchmark]}" ] && nodet_res[$benchmark]=0
		nodet_res[$benchmark]=$(awk "BEGIN {print ${nodet_res[$benchmark]}+$(grep "^runtime" $file | grep -oE "[0-9]+\.[0-9]+")}")
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

printf "Final results\n"
printf "Benchmark\tBaseline\tWith optimization\n"
for i in ${BENCHMARKS}; do
	with_opt=$(awk "BEGIN {print ${det1_res[$i]}/${nodet_res[$i]}}")
	without_opt=$(awk "BEGIN {print ${det2_res[$i]}/${nodet_res[$i]}}")
	printf "%s\t%f\t%f\n" $i $without_opt $with_opt
done
