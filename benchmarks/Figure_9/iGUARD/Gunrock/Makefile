BENCHMARKS   ?= louvain bc pr_nibble sm color
HOOKLIB      ?= ../../../../nvbit_release/tools/detector/detector.so
RUNS         ?= 1
PREFIX_NODET ?= NODET
PREFIX_DET   ?= IGUARD

run:
	mkdir -p ../results/
	for runs in `seq 1 1 ${RUNS}`; do \
		for file in $(BENCHMARKS); do \
			echo "" > ../results/${PREFIX_NODET}$${runs}_$${file}.raw; \
			time -f "MAXCPUMEM\t$$file\t%M\nruntime\t$$file\t%e\n" timeout 10m $(MAKE) run_$$file HOOKLIB="" >> ../results/${PREFIX_NODET}$${runs}_$${file}.raw 2>&1; \
		done \
	done
	
	mkdir -p ../results/
	for runs in `seq 1 1 ${RUNS}`; do \
		for file in $(BENCHMARKS); do \
			echo "" > ../results/${PREFIX_DET}$${runs}_$${file}.raw; \
			time -f "MAXCPUMEM\t$$file\t%M\nruntime\t$$file\t%e\n" timeout 10m $(MAKE) run_$$file HOOKLIB=${HOOKLIB} >> ../results/${PREFIX_DET}$${runs}_$${file}.raw 2>&1; \
		done \
	done

run_louvain:
	LD_PRELOAD=${HOOKLIB} ./bin/louvain market \
	./input/louvain --omp-threads=32 --advance-mode=ALL_EDGES --unify-segments=true

run_bc:
	LD_PRELOAD=${HOOKLIB} ./bin/bc market ./input/bc --undirected --src=0

run_pr_nibble:
	LD_PRELOAD=${HOOKLIB} ./bin/pr_nibble market ./input/pr_nibble

run_sm:
	LD_PRELOAD=${HOOKLIB} BYTE_GRAN=1 ./bin/sm market ./input/sm1 --pattern-graph-type=market \
	--pattern-graph-file=./input/sm2 \
	--undirected=1 --pattern-undirected=1 --num-runs=10 --quiet=false

run_color:
	LD_PRELOAD=${HOOKLIB} ./bin/color market ./input/color --undirected --device=0
