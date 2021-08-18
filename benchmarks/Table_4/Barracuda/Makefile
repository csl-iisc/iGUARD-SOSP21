DIRS         ?= Kilo-TM SHoC CUB Rodinia
RACEY_DIRS 	 ?= Kilo-TM SHoC
RUNS         ?= 1
PREFIX_NODET ?= NODET
PREFIX_DET   ?= BARR

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
			./extract.sh "../results/${PREFIX_DET}1_";\
			cd ..;\
		fi;\
	done
