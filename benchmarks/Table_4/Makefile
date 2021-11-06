PREFIX_NODET1 ?= iGUARD/results/NODET
PREFIX_NODET2 ?= Barracuda/results/NODET
PREFIX_DET1   ?= iGUARD/results/IGUARD
PREFIX_DET2   ?= Barracuda/results/BARR
RUNS          ?= 5
BENCHMARKS    ?= matrix-mult 1dconv graph-con reduction rule-110 uts graph-color \
				 conjugGMB reduceMB grid_sync louvain pr_nibble sm color \
				 mis cc test_slab_hash prims interac hashtable shoc_bfs grid_barrier
NO_RACE_BENCH := b_radix_sort b_reduce b_scan d_part_flag d_part_if d_radix_sort \
				 d_reduce d_scan d_sel_flag d_sel_if d_sel_unique d_sort_find\
				 dwt2d hotspot hybridsort kmeans needle nn pathfinder srad warpAA

run:
	$(MAKE) run_iGUARD
	$(MAKE) run_barracuda
	
	$(MAKE) extract
	
run_iGUARD:
	cd iGUARD; \
	$(MAKE) RUNS=${RUNS};
	
run_barracuda:
	cd Barracuda; \
	$(MAKE) RUNS=${RUNS};
	
extract:
	$(MAKE) extract_iGUARD
	$(MAKE) extract_BARR
	$(MAKE) extract_final
	$(MAKE) -s extract_final > results.txt
	echo "Stored results in benchmarks/Table_4/results.txt"

extract_iGUARD:
	cd iGUARD; \
	$(MAKE) extract RUNS=${RUNS} > results.out; \
	cd ..
	
extract_BARR:
	cd Barracuda; \
	$(MAKE) extract RUNS=${RUNS} > results.out; \
	cd ..

extract_final:
	./extract.sh ${PREFIX_DET1} ${PREFIX_DET2} "${BENCHMARKS}" "${NO_RACE_BENCH}"
