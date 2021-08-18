BENCHMARKS   ?= grid_sync
HOOKLIB      ?= ../../../../nvbit_release/tools/detector/detector.so
RUNS         ?= 1
PREFIX_NODET ?= NODET
PREFIX_DET   ?= IGUARD

.SILENT: run

run:
	mkdir -p ../results/
	for runs in `seq 1 1 ${RUNS}`; do \
		for file in $(BENCHMARKS); do \
			echo "" > ../results/${PREFIX_NODET}$${runs}_$${file}.raw; \
			time -f "MAXCPUMEM\t$$file\t%M\nruntime\t$$file\t%e\n" timeout 10m ./run.sh $$file  >> ../results/${PREFIX_NODET}$${runs}_$${file}.raw 2>&1; \
		done \
	done
	
	mkdir -p ../results/
	for runs in `seq 1 1 ${RUNS}`; do \
		for file in $(BENCHMARKS); do \
			echo "" > ../results/${PREFIX_DET}$${runs}_$${file}.raw; \
			time -f "MAXCPUMEM\t$$file\t%M\nruntime\t$$file\t%e\n" timeout 10m ./run.sh $$file ${HOOKLIB} >> ../results/${PREFIX_DET}$${runs}_$${file}.raw 2>&1; \
		done \
	done
