# iGUARD: <ins>I</ins>n-<ins>G</ins>P<ins>U</ins> <ins>A</ins>dvanced <ins>R</ins>ace <ins>D</ins>etection
We provide the source code and the setup for iGUARD, a tool to detect races in GPU programs. iGUARD instruments GPU programs to detect races in them. It uses NVIDIA's NVBit [[1]](#references), a GPU binary instrumenter, as the framework for instrumentation. 

This README provides a peek into different parameters of the tool and a very high-level view of source code organization.    

## Benchmarks
To replicate the results given in the paper, we provide precompiled application binaries. Full details are given in the **[README in the benchmarks folder](benchmarks/README.md)**.

Required software packages can be installed through apt using the following command:
```
sudo apt-get install -y wget bc gcc time gawk libtbb-dev
```

## Hardware and software requirements
iGUARD is built on top of NVBit (version 1.4) and shares its requirements, listed below:
* SM compute capability: >= 3.5 && <= 8.0
* Host CPU: x86\_64, ppc64le, aarch64
* OS: Linux
* GCC version : >= 5.3.0 for x86\_64; >= 7.4.0 for ppc64le and aarch64
* CUDA version: >= 10.1
* CUDA driver version: <= 450.00

Currently no Embedded GPUs or ARMs host are supported.


## Behind the scenes: iGUARD's parameters, setup, and source code 
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

## References
**[1]** NVBit [[Paper]](https://github.com/NVlabs/NVBit/releases/download/v1.0/MICRO_19_NVBit.pdf) [[Repository]](https://github.com/NVlabs/NVBit)
