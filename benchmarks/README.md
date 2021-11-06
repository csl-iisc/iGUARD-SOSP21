# iGUARD: <ins>I</ins>n-<ins>G</ins>P<ins>U</ins> <ins>A</ins>dvanced <ins>R</ins>ace <ins>D</ins>etection Benchmarks
We provide the application binaries used in the evaluation of iGUARD for ease of use. However, we also provide links to the source code of applications/benchmark suites toward the end of this README. 

This README is divided into two major parts. In the first part, we describe the system requirements and bash scripts for reproducing the main results in the SOSP paper. In the second part, we provide a Docker container if one wishes to avoid manually installing the dependencies. 

Required software packages can be installed through apt using the following command:
```
sudo apt-get install -y wget bc gcc time gawk libtbb-dev
```

## Hardware and software requirements
Benchmarks were tested on machines with the following specs:
* Host CPU: x86\_64  (preferably Intel Xeon)
* OS: Ubuntu 20.04 (Linux kernel v 5.4.0-72)
* CUDA version: 11.0
* GPU: NVIDIA Turing architecture (preferably RTX Titan)
* CUDA driver version: >= 450.00


## Steps to setup and replicate results
The following are the steps required to reproduce the results, along with the expected run time. All commands should be run in the main repository folder.
 1. **Downloading NVBit and compiling detector. [5 - 10 minutes]**
 2. **Replicating Table 4. [~3 hours]**
 3. **Replicating Figure 11. [~3 hours]**
 4. **Replicating Figure 12. [~30 minutes]**

### Downloading NVBit and compiling detector  [5 - 10 minutes]
The following command downloads, extracts, sets up NVBit, and compiles our iGUARD tool:
```
make setup
```
The compiled race detector, iGUARD, can be found at: *nvbit_release/tools/detector/detector.so*
To delete the installation, run the following command:
```
make clean_detector
```

### Replicating primary results (Figures and Tables)
The [benchmarks](benchmarks/) folder contains all the binaries and scripts required to generate the results contained in the paper. Each subfolder in this folder is dedicated to generating a single figure/table. 

During execution, you may get "Error 124" or "Error 134" from make. These are normal, caused when benchmarks time out, and can safely be ignored. The time-outs happen either due to the presence of races (bugs) in the applications or due to the slowness of another race detector, Barracuda [[1]](#references), that we quantitatively compare against.    

**Table 4 [~3 hours]**     
Run the following command in the main repository folder:
```
make table_4
```
This will run the appropriate benchmarks on iGUARD and Barracuda and report the number of races detected by each. Barracuda is a prior work that we quantitatively compare against.

A single race (bug) in a program can manifest multiple times and involve different load/store operations. This is particularly true because iGUARD does not stop its detection on detecting a race in the program. iGUARD notes down the races it observed but continues to execute the program. The outputs of the race detector are parsed to count the number of unique races caught. The scripts responsible for parsing can be found inside the respective subfolders in *[benchmarks/Table_4](benchmarks/Table_4/)*, called *extract.sh*. 

Raw outputs for iGUARD and Barracuda will be contained in *benchmarks/Table_4/iGUARD/results/* and *benchmarks/Table_4/Barracuda/results/* respectively. Files starting with IGUARD_ and BARR_ contain the outputs when iGUARD and Barracuda are used, respectively.

Final parsed results will be outputted in the terminal and are also contained at *benchmarks/Table_4/results.txt* in tab-separated format.    

Races are non-deterministic by their very nature. Not all races will manifest in every execution. The happens-before race detection philosophy that iGUARD partially relies upon can catch races only if they manifest. The scripts are set up to run each program five times by default to step aside possible non-determinism in the total number of races reported. If any slight variance is observed between the number of races reported by the tool and that in the paper, rerunning it should resolve the difference. 

**Figure 11 [~3 hours]**    
Run the following command in the main repository folder:
```
make figure_11
```
This will run the appropriate benchmarks on iGUARD and Barracuda and measure the run time.    

Raw outputs and run times for iGUARD and Barracuda will be contained in *benchmarks/Figure_11/iGUARD/results/* and *benchmarks/Figure_11/Barracuda/results/* respectively. Output files starting with NODET_ contain the outputs when no detection is run, while IGUARD_ and BARR_ are when iGUARD and Barracuda are used, respectively.

Final normalized results will be outputted in the terminal and are also contained at *benchmarks/Figure_11/results.txt* in tab-separated format. This can be imported into a spreadsheet of your choice to generate the appropriate figure.

**Figure 12 [~30 minutes]**     
Run the following command in the main repository folder:
```
make figure_12
```
This will run the appropriate benchmarks on iGUARD with and without lock contention optimizations (Section 6.5 in the paper) and measure the run time. 

Raw outputs with and without contention optimizations will be kept in *benchmarks/Figure_12/results/*. Output files starting with NODET_ contain the outputs when no detection is run, while IGUARD_OPT_ and IGUARD_ are when iGUARD is run with and without the optimizations, respectively.

Final normalized results will be outputted in the terminal and are also contained at *benchmarks/Figure_12/results.txt* in tab-separated format. This can be imported into a spreadsheet of your choice to generate the appropriate figure.



## Docker setup (alternative)
For convenience, we also provided a Dockerfile that has all the required dependencies. This is useful if one does not wish to install the dependencies manually. The following are the steps required to use this file.
1. Install Docker: https://docs.docker.com/engine/install/
2. Setup the appropriate repository for the nvidia-container-runtime: https://nvidia.github.io/nvidia-container-runtime/
3. Install nvidia-container-runtime: `sudo apt-get install nvidia-container-runtime`
4. Restart Docker for the changes to take effect: `sudo systemctl restart docker`
5. Build the dockerfile: `sudo docker build -t test .`
6. Generate required results.    
**Table 4**: `sudo docker run --gpus all test make table_4`    
**Figure 11**: `sudo docker run --gpus all test make figure_11`    
**Figure 12**: `sudo docker run --gpus all test make figure_12`    

Results will be outputted in tab-separated format directly to the terminal. For figures, the output is the normalized run times used to generate the graphs. For the table, the output is the number of races caught by the different detectors for each benchmark.    

Due to software overheads by Docker, performance numbers may vary slightly from those reported in the paper, but relative trends should remain the same.


## Workloads (GPU benchmark suites, libraries and applications)
The following table lists the workloads used in the evaluation of the submission version of the paper. This repository contains pre-compiled binaries from the open-source benchmark suites listed below. If one wishes, she/he can compile the workloads from source too. 


| Suite      | Information | Code | Description |
| ---------- | -------- | -------- | - |
| ScoR       | [[Paper]](https://www.csa.iisc.ac.in/~arkapravab/papers/isca20_ScoRD.pdf)     | [[Github]](https://github.com/csl-iisc/ScoR) | Racey applications using scopes. |
| CG         | [[Blog]](https://developer.nvidia.com/blog/cooperative-groups/)     | [[Github]](https://github.com/NVIDIA/cuda-samples) | Sample applications using NVIDIA Cooperative Groups. |
| Gunrock    | [[Paper]](https://escholarship.org/uc/item/9gj6r1dj)     | [[Github]](https://github.com/gunrock/gunrock)     | Graph processing system for GPUs. |
| LonestarGPU| [[Paper]](http://cs.txstate.edu/~mb92/papers/iiswc12.pdf)     | [[Github]](https://github.com/IntelligentSoftwareSystems/Galois/tree/master/lonestar/analytics/gpu)     | GPU applications with irregular behaviour.
| SlabHash   | [[Paper]](https://par.nsf.gov/servlets/purl/10062407)     | [[Github]](https://github.com/owensgroup/SlabHash)     | A warp-oriented dynamic hash table for GPUs
| cuML       | [[Website]](https://docs.rapids.ai/api/cuml/stable/)     | [[Github]](https://github.com/rapidsai/cuml)     | Suite of libraries that implement machine learning algorithms and mathematical primitives
| Kilo-TM    | [[Paper]](https://ieeexplore.ieee.org/document/6174995)     | [[Github]](https://github.com/upenn-acg/barracuda/tree/master/benchmarks/gpu-tm)     | GPU applications with fine-grained communication between threads. | 
| SHoC       | [[Paper]](https://dl.acm.org/doi/10.1145/1735688.1735702)     | [[Github]](https://github.com/vetter/shoc) | Applications with heterogeneous compute.
| CUB        | [[Website]](https://nvlabs.github.io/cub/)     | [[Github]](https://github.com/NVIDIA/cub)     | Parallel compute primitives for GPUs. |
| Rodinia    | [[Paper]](https://www.cs.virginia.edu/~skadron/Papers/rodinia_iiswc09.pdf)     | [[Website]](http://lava.cs.virginia.edu/Rodinia/download.htm)     | Benchmarks for heterogeneous compute.


## References
**[1]** Barracuda [[Paper]](https://www.cs.uic.edu/~mansky/barracuda.pdf) [[Repository]](https://github.com/upenn-acg/barracuda)
