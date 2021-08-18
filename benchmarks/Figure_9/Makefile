PREFIX_NODET1 ?= iGUARD/results/NODET
PREFIX_NODET2 ?= Barracuda/results/NODET
PREFIX_DET1   ?= iGUARD/results/IGUARD
PREFIX_DET2   ?= Barracuda/results/BARR
RUNS          ?= 5
BENCHMARKS    ?= matrix-mult 1dconv graph-con reduction rule-110 uts graph-color \
				 conjugGMB reduceMB warpAA louvain bc pr_nibble sm color \
				 mis cc interac hashtable shoc_bfs \
				 b_radix_sort b_reduce b_scan d_part_flag d_part_if d_radix_sort \
				 d_reduce d_scan d_sel_flag d_sel_if d_sel_unique d_sort_find\
				 dwt2d hotspot hybridsort kmeans needle nn pathfinder srad

.SILENT: run extract extract_final

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
	$(MAKE) extract_final
	$(MAKE) -s extract_final > results.txt
	echo "\nStored results in benchmarks/Figure_9/results.txt"
	
extract_final:
	./extract.sh ${PREFIX_NODET1} ${PREFIX_NODET2} ${PREFIX_DET1} ${PREFIX_DET2} "${BENCHMARKS}" ${RUNS}
