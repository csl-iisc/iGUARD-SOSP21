BENCHMARKS1  ?= matrix-mult 1dconv graph-con conjugGMB reduceMB warpAA shoc_bfs
BENCHMARKS2	 ?= mis cc
HOOKLIB      ?= ../../nvbit_release/tools/detector/detector.so
PREFIX_NODET ?= NODET
PREFIX_DET1  ?= IGUARD_OPT
PREFIX_DET2  ?= IGUARD
RUNS         ?= 3
OUTPUT_BENCH ?= matrix-mult 1dconv graph-con conjugGMB reduceMB warpAA mis cc shoc_bfs

.SILENT: run extract extract_final

run:
	mkdir -p results/
	for runs in `seq 1 1 ${RUNS}`; do \
		for bm in $(BENCHMARKS1); do \
			echo "Running " $$bm " run " $${runs} ;\
			echo "" > results/${PREFIX_NODET}$${runs}_$${bm}.raw; \
			time -f "MAXCPUMEM\t$$file\t%M\nruntime\t$$file\t%e\n" ./run.sh $$bm  >> results/${PREFIX_NODET}$${runs}_$$bm.raw 2>&1; \
		done \
	done
	
	mkdir -p results/
	for runs in `seq 1 1 ${RUNS}`; do \
		for bm in $(BENCHMARKS2); do \
			echo "Running " $$bm " run " $${runs} ;\
			echo "" > results/${PREFIX_NODET}$${runs}_$${bm}.raw; \
			time -f "MAXCPUMEM\t$$file\t%M\nruntime\t$$file\t%e\n" ./run2.sh $$bm  >> results/${PREFIX_NODET}$${runs}_$$bm.raw 2>&1; \
		done \
	done
	
	for runs in `seq 1 1 ${RUNS}`; do \
		for bm in $(BENCHMARKS1); do \
			echo "Running " $$bm " run " $${runs} ;\
			echo "" > results/${PREFIX_DET1}$${runs}_$${bm}.raw; \
			time -f "MAXCPUMEM\t$$file\t%M\nruntime\t$$file\t%e\n" ./run.sh $$bm ${HOOKLIB} >> results/${PREFIX_DET1}$${runs}_$$bm.raw 2>&1; \
		done \
	done
	
	for runs in `seq 1 1 ${RUNS}`; do \
		for bm in $(BENCHMARKS2); do \
			echo "Running " $$bm " run " $${runs} ;\
			echo "" > results/${PREFIX_DET1}$${runs}_$${bm}.raw; \
			time -f "MAXCPUMEM\t$$file\t%M\nruntime\t$$file\t%e\n" ./run2.sh $$bm ${HOOKLIB} >> results/${PREFIX_DET1}$${runs}_$$bm.raw 2>&1; \
		done \
	done
	
	for runs in `seq 1 1 ${RUNS}`; do \
		for bm in $(BENCHMARKS1); do \
			echo "Running " $$bm " run " $${runs} ;\
			echo "" > results/${PREFIX_DET2}$${runs}_$${bm}.raw; \
			CONT_OPT=0 time -f "MAXCPUMEM\t$$file\t%M\nruntime\t$$file\t%e\n" ./run.sh $$bm ${HOOKLIB} >> results/${PREFIX_DET2}$${runs}_$$bm.raw 2>&1; \
		done \
	done
	
	for runs in `seq 1 1 ${RUNS}`; do \
		for bm in $(BENCHMARKS2); do \
			echo "Running " $$bm " run " $${runs} ;\
			echo "" > results/${PREFIX_DET2}$${runs}_$${bm}.raw; \
			CONT_OPT=0 time -f "MAXCPUMEM\t$$file\t%M\nruntime\t$$file\t%e\n" ./run2.sh $$bm ${HOOKLIB} >> results/${PREFIX_DET2}$${runs}_$$bm.raw 2>&1; \
		done \
	done
	
	$(MAKE) extract
	
extract:
	$(MAKE) extract_final
	$(MAKE) -s extract_final > results.txt
	echo "\nResults stored in benchmarks/Figure_10/results.txt"

extract_final:
	./extract.sh ${PREFIX_NODET} ${PREFIX_DET1} ${PREFIX_DET2} ${RUNS} "${OUTPUT_BENCH}"
