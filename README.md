# iGUARD: <ins>I</ins>n-<ins>G</ins>P<ins>U</ins> <ins>A</ins>dvanced <ins>R</ins>ace <ins>D</ins>etection
We provide the source code and the setup for iGUARD (SOSP AE submission #11), a tool to detect races in GPU programs. iGUARD instruments GPU programs to detect races in them. It uses NVIDIA's NVBit [[1]](#references), a GPU binary instrumenter, as the framework for instrumentation. 


We provide the application binaries used in the evaluation of iGUARD for ease of use. However, we also provide links to the source code of applications/benchmark suites toward the end of this README. 


This README is divided into three major parts. In the first part, we describe the system requirements and bash scripts for reproducing the main results in the SOSP paper. In the second part, we provide a Docker container if one wishes to avoid manually installing the dependencies. Finally, the README provides a peek into different parameters of the tool and a very high-level view of source code organization.  


## Hardware and software requirements
Benchmarks were tested on machines with the following specs:
* Host CPU: x86\_64  (preferably Intel Xeon)
* OS: Ubuntu 20.04 (Linux kernel v 5.4.0-72)
* CUDA version: 11.0
* GPU: NVIDIA Turing architecture (preferably RTX Titan)
* CUDA driver version: >= 450.00

Required software packages can be installed through apt using the following command:
```
sudo apt-get install -y wget bc gcc time gawk libtbb-dev
```

## Steps to setup and replicate results
The following are the steps required to reproduce the results, along with the expected run time. All commands should be run in the main repository folder.
 1. **Downloading NVBit and compiling detector. [5 - 10 minutes]**
 2. **Replicating Table 4. [~3 hours]**
 3. **Replicating Figure 9. [~3 hours]**
 4. **Replicating Figure 10. [~30 minutes]**

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

During execution, you may get "Error 124" or "Error 134" from make. These are normal, caused when benchmarks time out, and can safely be ignored. The time-outs happen either due to the presence of races (bugs) in the applications or due to the slowness of another race detector, Barracuda [[2]](#references), that we quantitatively compare against.  

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

**Figure 9 [~3 hours]**    
Run the following command in the main repository folder:
```
make figure_9
```
This will run the appropriate benchmarks on iGUARD and Barracuda and measure the run time.  

Raw outputs and run times for iGUARD and Barracuda will be contained in *benchmarks/Figure_9/iGUARD/results/* and *benchmarks/Figure_9/Barracuda/results/* respectively. Output files starting with NODET_ contain the outputs when no detection is run, while IGUARD_ and BARR_ are when iGUARD and Barracuda are used, respectively.

Final normalized results will be outputted in the terminal and are also contained at *benchmarks/Figure_9/results.txt* in tab-separated format. This can be imported into a spreadsheet of your choice to generate the appropriate figure.

**Figure 10 [~30 minutes]**     
Run the following command in the main repository folder:
```
make figure_10
```
This will run the appropriate benchmarks on iGUARD with and without lock contention optimizations (Section 6.5 in the paper) and measure the run time. 

Raw outputs with and without contention optimizations will be kept in *benchmarks/Figure_10/results/*. Output files starting with NODET_ contain the outputs when no detection is run, while IGUARD_OPT_ and IGUARD_ are when iGUARD is run with and without the optimizations, respectively.

Final normalized results will be outputted in the terminal and are also contained at *benchmarks/Figure_10/results.txt* in tab-separated format. This can be imported into a spreadsheet of your choice to generate the appropriate figure.



## Docker setup (alternative)
For convenience, we also provided a Dockerfile that has all the required dependencies. This is useful if one does not wish to install the dependencies manually. The following are the steps required to use this file.
1. Install Docker: https://docs.docker.com/engine/install/
2. Setup the appropriate repository for the nvidia-container-runtime: https://nvidia.github.io/nvidia-container-runtime/
3. Install nvidia-container-runtime: `sudo apt-get install nvidia-container-runtime`
4. Restart Docker for the changes to take effect: `sudo systemctl restart docker`
5. Build the dockerfile: `sudo docker build -t test .`
6. Generate required results.    
**Table 4**: `sudo docker run --gpus all test make table_4`    
**Figure 9**: `sudo docker run --gpus all test make figure_9`    
**Figure 10**: `sudo docker run --gpus all test make figure_10`    

Results will be outputted in tab-separated format directly to the terminal. For figures, the output is the normalized run times used to generate the graphs. For the table, the output is the number of races caught by the different detectors for each benchmark.    

Due to software overheads by Docker, performance numbers may vary slightly from those reported in the paper, but relative trends should remain the same.

## Behind the scenes: iGUARD's parameters, setup, and source code 
This is an optional section that provides more details about the tool itself for those who want to extend the tool in the future. 
### Compilation
To download NVBit and compile the detector, run the following command:
```
make setup
```
The compiled detector can be found at *nvbit_release/tools/detector/detector.so*. 

### Running the race detector (iGUARD)
Once compiled, the detector can be run on binaries containing NVIDIA GPU code by setting the LD_PRELOAD environment variable. For example, to run the detector on an application binary called *app.exe* contained in the main repository folder, you would run the following command:
```
LD_PRELOAD=./nvbit_release/tools/detector/detector.so ./app.exe
```
Compiling the application binary with `-lineinfo` flag allows iGUARD to output line numbers when races are detected. Otherwise, SASS offsets are used.

### Race detection options (parameters)
We provide several knobs that allow users to change how the detection works. The major ones are listed below:

 - BYTE_GRAN: The granularity of a single data item (in bytes) considered by the detector. (default = 4)
 - CONT_OPT: Whether to perform contention optimizations (exponential backoff and detection coalescing) during race detection. (default = 1)
 - EXIT: Whether to quit on encountering the first race. (default = 0)
 - TIMEOUT: Time-out in seconds after which the application is terminated. 0 means never. (default = 0)

To use these knobs, set them as environment variables when performing race detection. For example, to time-out after 4 seconds when performing detection on app.exe, we run the following command:
```
TIMEOUT=4 LD_PRELOAD=./nvbit_release/tools/detetor/detector.so ./app.exe
```

### Source code
The source code for the iGUARD race detector is found in the *[detector/](detector/)* folder.
The major files are as follows:    
 - **[detector.cu](detector/detector.cu)**: This contains the CPU-side code for the detector.  This includes allocating memory for metadata, the binary instrumentation process, and outputting caught races to the user.   
- **[inject_funcs.cu](detector/inject_funcs.cu)**: This contains the CUDA code run on the GPU after instrumentation. This includes incrementing relevant counters on synchronization operations, adding/removing locks from the lock table, and performing the in-GPU race detection.

## Workloads (GPU benchmark suites, libraries and applications)
The following table lists the workloads used in the evaluation of the submission version of the paper. This repository contains pre-compiled binaries from the open-source benchmark suites listed below. If one wishes, she/he can compile the workloads from source too. 


| Suite      | Information | Code | Description |
| ---------- | -------- | -------- | - |
| ScoR       | [[Paper]](https://www.csa.iisc.ac.in/~arkapravab/papers/isca20_ScoRD.pdf)     | [[Github]](https://github.com/csl-iisc/ScoR) | Racey applications using scopes. |
| CG         | [[Blog]](https://developer.nvidia.com/blog/cooperative-groups/)     | [[Github]](https://github.com/NVIDIA/cuda-samples) | Sample applications using NVIDIA Cooperative Groups. |
| Gunrock     | [[Paper]](https://escholarship.org/uc/item/9gj6r1dj)     | [[Github]](https://github.com/gunrock/gunrock)     | Graph processing system for GPUs. |
| LonestarGPU | [[Paper]](http://cs.txstate.edu/~mb92/papers/iiswc12.pdf)     | [[Github]](https://github.com/IntelligentSoftwareSystems/Galois/tree/master/lonestar/analytics/gpu)     | GPU applications with irregular behaviour.
| Kilo-TM  | [[Paper]](https://ieeexplore.ieee.org/document/6174995)     | [[Github]](https://github.com/upenn-acg/barracuda/tree/master/benchmarks/gpu-tm)     | GPU applications with fine-grained communication between threads. | 
| SHoC     | [[Paper]](https://dl.acm.org/doi/10.1145/1735688.1735702)     | [[Github]](https://github.com/vetter/shoc) | Applications with heterogeneous compute.
| CUB      | [[Website]](https://nvlabs.github.io/cub/)     | [[Github]](https://github.com/NVIDIA/cub)     | Parallel compute primitives for GPUs. |
| Rodinia  | [[Paper]](https://www.cs.virginia.edu/~skadron/Papers/rodinia_iiswc09.pdf)     | [[Website]](http://lava.cs.virginia.edu/Rodinia/download.htm)     | Benchmarks for heterogeneous compute.


## References
**[1]** NVBit [[Paper]](https://github.com/NVlabs/NVBit/releases/download/v1.0/MICRO_19_NVBit.pdf) [[Repository]](https://github.com/NVlabs/NVBit)    
**[2]** Barracuda [[Paper]](https://www.cs.uic.edu/~mansky/barracuda.pdf) [[Repository]](https://github.com/upenn-acg/barracuda)
