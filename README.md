# iGUARD: <u>I</u>n-<u>G</u>P<u>U</u> <u>A</u>dvanced <u>R</u>ace <u>D</u>etection
## Requirements
### Detector
iGUARD is built on top of NVBit (version 1.4) and shares its requirements, listed below:
* SM compute capability: >= 3.5 && <= 8.0
* Host CPU: x86\_64, ppc64le, aarch64
* OS: Linux
* GCC version : >= 5.3.0 for x86\_64; >= 7.4.0 for ppc64le and aarch64
* CUDA version: >= 10.1
* CUDA driver version: <= 450.00

Currently no Embedded GPUs or ARMs host are supported.
### Benchmarks
Precompiled benchmarks were tested on machines with the following specs:
* Host CPU: x86\_64
* OS: Linux 18.04/20.04
* CUDA version: 11.0
* GPU: NVIDIA Turing (RTX Titan)

### Quick Instructions
To download, extract, and setup NVBit, run the following command:
`make setup`

To delete the installed NVBit, run the following command:
`make clean_detector`

