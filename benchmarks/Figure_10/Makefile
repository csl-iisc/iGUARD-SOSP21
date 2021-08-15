BENCHMARKS   ?= matrix-mult graph-con #1dconv
HOOKLIB      ?= ../../nvbit_release/tools/detector/detector.so
PREFIX_NODET ?= NODET
PREFIX_DET1  ?= IGUARD_OPT
PREFIX_DET2  ?= IGUARD
RUNS         ?= 3

run:
	mkdir -p results/
	for runs in `seq 1 1 ${RUNS}`; do \
		for bm in $(BENCHMARKS); do \
			echo $$bm ;\
			echo "" > results/${PREFIX_NODET}$${runs}_$${bm}.raw; \
			time -f "MAXCPUMEM\t$$file\t%M\nruntime\t$$file\t%e\n" ./run.sh $$bm  >> results/${PREFIX_NODET}$${runs}_$$bm.raw 2>&1; \
		done \
	done
	
	for runs in `seq 1 1 ${RUNS}`; do \
		for bm in $(BENCHMARKS); do \
			echo $$bm ;\
			echo "" > results/${PREFIX_DET}$${runs}_$${bm}.raw; \
			time -f "MAXCPUMEM\t$$file\t%M\nruntime\t$$file\t%e\n" ./run.sh $$bm ${HOOKLIB} >> results/${PREFIX_DET}$${runs}_$$bm.raw 2>&1; \
		done \
	done
	
	for runs in `seq 1 1 ${RUNS}`; do \
		for bm in $(BENCHMARKS); do \
			echo $$bm ;\
			echo "" > results/${PREFIX_DET}$${runs}_$${bm}.raw; \
			CONT_OPT=0 time -f "MAXCPUMEM\t$$file\t%M\nruntime\t$$file\t%e\n" ./run.sh $$bm ${HOOKLIB} >> results/${PREFIX_DET}$${runs}_$$bm.raw 2>&1; \
		done \
	done
