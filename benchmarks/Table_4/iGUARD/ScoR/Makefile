BENCHMARKS   ?= matrix-mult 1dconv graph-con1 graph-con2 graph-con3 graph-con4 reduction rule-1101 rule-1102 uts1 uts2 graph-color1 graph-color2
HOOKLIB      ?= ../../../../nvbit_release/tools/detector/detector.so
RUNS         ?= 1
PREFIX_NODET ?= NODET
PREFIX_DET   ?= IGUARD

.SILENT: run

run:	
	mkdir -p ../results/
	for runs in `seq 1 1 ${RUNS}`; do \
		for file in $(BENCHMARKS); do \
			echo "" > ../results/${PREFIX_DET}$${runs}_$${file}.raw; \
			TIMEOUT=20 ./run.sh $$file ${HOOKLIB} >> ../results/${PREFIX_DET}$${runs}_$${file}.raw 2>&1; \
		done \
	done
