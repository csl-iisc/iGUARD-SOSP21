BENCHMARKS   ?= hashtable interac
HOOKLIB      ?= ../libhook.so
RUNS         ?= 1
PREFIX_NODET ?= NODET
PREFIX_DET   ?= BARR


run:
	mkdir -p ../results/
	for runs in `seq 1 1 ${RUNS}`; do \
		for file in $(BENCHMARKS); do \
			echo "" > ../results/${PREFIX_DET}$${runs}_$${file}.raw; \
			time -f "MAXCPUMEM\t$$file\t%M\nruntime\t$$file\t%e\n" timeout 10m $(MAKE) run_$$file HOOKLIB=${HOOKLIB} >> ../results/${PREFIX_DET}$${runs}_$${file}.raw 2>&1; \
		done \
	done
	
run_interac:
	LD_PRELOAD=${HOOKLIB} ./bin/interac
	
run_hashtable:
	LD_PRELOAD=${HOOKLIB} ./bin/hashtable -noprompt -numThreads=8 -numBlocks=8 -quiet
