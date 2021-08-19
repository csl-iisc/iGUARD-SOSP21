DIRS         ?= ScoR CG NVlib_CG Gunrock LS Kilo-TM SHoC CUB Rodinia
RACEY_DIRS 	 ?= ScoR CG NVlib_CG Gunrock LS Kilo-TM SHoC
RUNS         ?= 1
PREFIX_NODET ?= NODET
PREFIX_DET   ?= IGUARD

run:
	for i in ${DIRS}; do \
		cd $$i;      \
		$(MAKE) run RUNS=${RUNS} PREFIX_NODET=${PREFIX_NODET} PREFIX_DET=${PREFIX_DET}; \
		cd ..;       \
	done
	
extract:
	for folder in ${RACEY_DIRS}; do \
		if [ -d "$$folder" ]; then   \
			cd $$folder;             \
			./extract.sh "../results/${PREFIX_DET}" ${RUNS};\
			cd ..;\
		fi;\
	done
