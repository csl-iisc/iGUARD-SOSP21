BENCHMARKS   ?= dwt2d hotspot hybridsort kmeans needle nn pathfinder srad
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

run_dwt2d:
	LD_PRELOAD=${HOOKLIB} ./bin/dwt2d dwt2d -d 192x192 -f -5 -l 3

run_hotspot:
	LD_PRELOAD=${HOOKLIB} ./bin/hotspot 512 2 2 data/hotspot1 data/hotspot2 output.out

run_hybridsort:
	LD_PRELOAD=${HOOKLIB} ./bin/hybridsort r

run_kmeans:
	LD_PRELOAD=${HOOKLIB} ./bin/kmeans -i data/kdd_cup 

run_needle:
	LD_PRELOAD=${HOOKLIB} ./bin/needle 2048 10

run_nn:
	LD_PRELOAD=${HOOKLIB} ./bin/nn filelist_4 -r 5 -lat 30 -lng 90 -q

run_pathfinder:
	LD_PRELOAD=${HOOKLIB} ./bin/pathfinder 100000 100 20 

run_srad:
	LD_PRELOAD=${HOOKLIB} ./bin/srad 2048 2048 0 127 0 127 0.5 2
