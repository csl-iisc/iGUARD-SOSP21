.PHONY: setup detector figure_10

setup: nvbit_release/tools/detector	
	$(MAKE) detector

detector: nvbit_release/tools/detector
	cd nvbit_release/tools/detector; \
	$(MAKE)

nvbit_release/tools/detector: nvbit_release/tools/ detector/
	cp -r detector/ nvbit_release/tools/

nvbit-Linux-x86_64-1.4.tar.bz2:
	wget https://github.com/NVlabs/NVBit/releases/download/1.4/nvbit-Linux-x86_64-1.4.tar.bz2
	
nvbit_release/tools/: nvbit-Linux-x86_64-1.4.tar.bz2
	tar -xf nvbit-Linux-x86_64-1.4.tar.bz2
	
clean_detector:
	rm -rf nvbit_release/
	rm nvbit-Linux-x86_64-1.4.tar.bz2

table_4:
	cd benchmarks/Table_4; \
	$(MAKE)

figure_9:
	cd benchmarks/Figure_9; \
	$(MAKE)

figure_10:
	cd benchmarks/Figure_10; \
	$(MAKE)
