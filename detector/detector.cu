/********************************************************************************************
 * Copyright (c) 2021 Indian Institute of Science
 * All rights reserved.
 *
 * Developed by:    Aditya K Kamath
 *                  Computer Systems Lab
 *                  Indian Institute of Science
 *                  https://csl.csa.iisc.ac.in/
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * with the Software without restriction, including without limitation the 
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 *      > Redistributions of source code must retain the above copyright notice,
 *        this list of conditions and the following disclaimers.
 *      > Redistributions in binary form must reproduce the above copyright
 *        notice, this list of conditions and the following disclaimers in the
 *        documentation and/or other materials provided with the distribution.
 *      > Neither the names of Computer Systems Lab, Indian Institute of Science, 
 *        nor the names of its contributors may be used to endorse or promote products 
 *        derived from this Software without specific prior written permission.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
 * CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS WITH
 * THE SOFTWARE.
 *
 ********************************************************************************************/
#include "nvbit_tool.h"
#include "nvbit.h"

#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <tuple>
#include <chrono>

//#define DEBUG_OUT
/* for channel */
#include "utils/channel.hpp"

/* contains definition of the mem_access_t structure */
#include "helper.h"

/* Channel used to communicate from GPU to CPU receiving thread */
#define CHANNEL_SIZE (1l << 20)
static __managed__ ChannelDev channel_dev;
static ChannelHost channel_host;
std::chrono::time_point<std::chrono::high_resolution_clock> start;
std::chrono::time_point<std::chrono::high_resolution_clock> start_kernel;
std::chrono::time_point<std::chrono::high_resolution_clock> start_time;

double init_time = 0;
double instru_time = 0;
double thread_time = 0;
double kernel_time = 0;
double setup_time = 0;

size_t initial_used = 0;
size_t maxGPUMem = 0;
size_t maxCPUMem = 0;
size_t userGPUMem = 0;
uint64_t prev_used = 0;

/* Counters for race detection */
__managed__ void *counters[TOTAL_CTRS];
__managed__ int parameters[TOTAL_PARAMS];
__managed__ uint64_t mdArrayLen = 100;

/* Details of allocated memory */
__managed__ uint64_t *metadata[TOTAL_MD] = {NULL, NULL};
__managed__ uint64_t addrRangeStart = NULL;

/* receiving thread and its control variables */
pthread_t recv_thread;
volatile bool recv_thread_started = false;
volatile bool recv_thread_receiving = false;

/* skip flag used to avoid re-entry on the nvbit_callback when issuing
 * flush_channel kernel call */
bool skip_flag = false;
bool started = false;

uint64_t dataSize = 100;

/* global control variables for this tool */
uint32_t instr_begin_interval = 0;
uint32_t instr_end_interval = UINT32_MAX;
int verbose = 0;
int turned_off = 0;
int granularity = 4;
int check_locking = 1;
int check_its = 1;
//int lock_granularity = 0;
int race_exit = 0;
int md_scale = 1;
int timeout = 0;
int managed = 1;
int debug_out = 1;

/* opcode to id map and reverse map  */
std::unordered_map<std::string, int> opcode_to_id_map;
std::unordered_map<int, std::string> id_to_opcode_map;

std::unordered_map<CUdeviceptr, size_t> ptrSizes;

void nvbit_at_init() {
    setenv("CUDA_MANAGED_FORCE_DEVICE_ALLOC", "1", 1);
    GET_VAR_INT(
        instr_begin_interval, "INSTR_BEGIN", 0,
        "Beginning of the instruction interval where to apply instrumentation");
    GET_VAR_INT(
        instr_end_interval, "INSTR_END", UINT32_MAX,
        "End of the instruction interval where to apply instrumentation");
    GET_VAR_INT(verbose, "TOOL_VERBOSE", 0, "Enable verbosity inside the tool (def = 0)");
    GET_VAR_INT(turned_off, "TOOL_OFF", 0, "Do not instrument/detect (def = 0)");
    GET_VAR_INT(granularity, "BYTE_GRAN", 4, "Granularity of detection in bytes (def = 4)");
    GET_VAR_INT(check_locking, "CHECK_LOCKS", 1, "Whether to do lockset detection (def = 1)");
    //GET_VAR_INT(lock_granularity, "LOCK_GRAN", 0, "Granularity of lock tracking (0 = warp, 1 = thread; def = 0)");
    GET_VAR_INT(check_its, "CHECK_ITS", 1, "Whether to consider ITS when checking (def = 1)");
    GET_VAR_INT(race_exit, "EXIT", 0, "Quit on encountering error (def = 0)");
    GET_VAR_INT(md_scale, "MD_SCALE", 1, "Factor by which to scale down metadata (def = 1)");
    GET_VAR_INT(timeout, "TIMEOUT", 0, "Time in seconds after which to quit detection (0 = never; def = 0)");
    GET_VAR_INT(managed, "MANAGED", 1, "Force detector to use cudaMallocManaged for metadata (def = 1)");
    GET_VAR_INT(debug_out, "DEBUG", 0, "Output debug info (def = 0)");
    std::string pad(100, '-');
    printf("%s\n", pad.c_str());
}
/* Set used to avoid re-instrumenting the same functions multiple times */
std::unordered_set<CUfunction> already_instrumented;

void instrument_function_if_needed(CUcontext ctx, CUfunction func) {
    if(debug_out)
        start_time = std::chrono::high_resolution_clock::now();
    /* Get related functions of the kernel (device function that can be
     * called by the kernel) */
    std::vector<CUfunction> related_functions =
        nvbit_get_related_functions(ctx, func);

    /* add kernel itself to the related function vector */
    related_functions.push_back(func);

    /* iterate on function */
    for (auto f : related_functions) {
        /* "recording" function was instrumented, if set insertion failed
         * we have already encountered this function */
        if (!already_instrumented.insert(f).second) {
            continue;
        }
        const std::vector<Instr *> &instrs = nvbit_get_instrs(ctx, f);
        if (verbose) {
            printf("Inspecting function %s at address 0x%lx\n",
                   nvbit_get_func_name(ctx, f), nvbit_get_func_addr(f));
        }

        uint32_t cnt = 0;
        /* iterate on all the static instructions in the function */
        for (auto instr : instrs) {
            if (cnt < instr_begin_interval || cnt >= instr_end_interval ||
                    (instr->getMemOpType() == Instr::memOpType::NONE && 
                    !isBarrier(instr) && !isFence(instr) && !(isWarpBar(instr) && check_its))) {
                cnt++;
                continue;
            }
            
            cnt++;
            if (verbose) {
                instr->printDecoded();
            }
            
            if(isBarrier(instr)) {
                /* insert call to the instrumentation function with its
                 * arguments */
                nvbit_insert_call(instr, "instrument_barrier", IPOINT_AFTER);
                /* predicate value */
                nvbit_add_call_arg_pred_val(instr);
                nvbit_add_call_arg_const_val64(instr, (uint64_t)&counters[BARRIER]);
                continue;
            }
            
            if(isFence(instr)) {
                /* insert call to the instrumentation function with its
                 * arguments */
                nvbit_insert_call(instr, "instrument_fence", IPOINT_BEFORE);
                /* predicate value */
                nvbit_add_call_arg_pred_val(instr);
                nvbit_add_call_arg_const_val32(instr, getScope(instr));
                nvbit_add_call_arg_const_val64(instr, (uint64_t)&counters[WARP_CTRS]);
                nvbit_add_call_arg_const_val64(instr, (uint64_t)&counters[LOCKS]);
                nvbit_add_call_arg_const_val64(instr, (uint64_t)parameters);
                continue;
            }
            
            if(isWarpBar(instr) && check_its) {
                /* insert call to the instrumentation function with its
                 * arguments */
                nvbit_insert_call(instr, "instrument_warp_bar", IPOINT_BEFORE);
                /* predicate value */
                nvbit_add_call_arg_pred_val(instr);
                nvbit_add_call_arg_const_val64(instr, (uint64_t)&counters[WARP_BAR]);                
                continue;            
            }

            std::string opcode = std::string(nvbit_get_func_name(ctx, f)) + instr->getSass();
            
            if (opcode_to_id_map.find(opcode) ==
                opcode_to_id_map.end()) {
                int opcode_id = opcode_to_id_map.size();
                opcode_to_id_map[opcode] = opcode_id;
                
                char* file_name;
                char* dir_name;
                uint32_t line;
                bool avail = nvbit_get_line_info(ctx, f, instr->getOffset(), &file_name, &dir_name, &line);
                std::string output;
                if(avail)
                    output = std::string(file_name) + " - Kernel " + std::string(nvbit_get_func_name(ctx, f)) + ": Line " + std::to_string(line) + "\t" + instr->getSass();
                else
                    output = std::string(instr->getSass()) + " - Kernel " + std::string(nvbit_get_func_name(ctx, f)) + ": Sass offset " + std::to_string(instr->getOffset());
                id_to_opcode_map[opcode_id] = output;
            }
            
            int opcode_id = opcode_to_id_map[opcode];
            int mref_idx = 0;
            /* iterate on the operands */
            for (int i = 0; i < instr->getNumOperands(); i++) {
                /* get the operand "i" */
                const Instr::operand_t *op = instr->getOperand(i);

                if (op->type == Instr::operandType::MREF && 
                    (instr->getMemOpType() == Instr::memOpType::GENERIC
                    || instr->getMemOpType() == Instr::memOpType::GLOBAL)) {
                    /* insert call to the instrumentation function with its
                     * arguments */
                    nvbit_insert_call(instr, "instrument_mem", IPOINT_BEFORE);
                    /* predicate value */
                    nvbit_add_call_arg_pred_val(instr);
                    /* opcode id */
                    nvbit_add_call_arg_const_val32(instr, opcode_id);
                    /* memory reference 64 bit address */
                    nvbit_add_call_arg_mref_addr64(instr, mref_idx);
                    /* scope of operation */
                    nvbit_add_call_arg_const_val32(instr, getScope(instr));
                    /* load operation? */
                    nvbit_add_call_arg_const_val32(instr, (instr->isLoad() ? MASK_LOAD : 0) | 
                        (instr->isStore() ? MASK_STORE : 0) | (isStrong(instr) ? MASK_STRONG : 0) | 
                        (isCAS(instr) ? MASK_CAS : 0) | (isExch(instr) ? MASK_EXCH : 0));
                    /* add pointer to channel_dev*/
                    nvbit_add_call_arg_const_val64(instr, (uint64_t)metadata);
                    /* add pointer to channel_dev*/
                    nvbit_add_call_arg_const_val64(instr, (uint64_t)&addrRangeStart);
                    /* add pointer to channel_dev*/
                    nvbit_add_call_arg_const_val64(instr, (uint64_t)&mdArrayLen);
                    /* add pointer to channel_dev*/
                    nvbit_add_call_arg_const_val64(instr, (uint64_t)counters);
                    /* add pointer to channel_dev*/
                    nvbit_add_call_arg_const_val64(instr, (uint64_t)&channel_dev);
                    /* add pointer to channel_dev*/
                    nvbit_add_call_arg_const_val64(instr, (uint64_t)parameters);
                    /* add pointer to channel_dev*/
                    nvbit_add_call_arg_const_val32(instr, (uint32_t)instr->getSize());
                    mref_idx++;
                }
            }
        }
    }
    if(debug_out)
        instru_time += (double)std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::high_resolution_clock::now() - start_time).count() / 1000.0;
}

static void update_rss()
{
    size_t free = 0, total = 0;
	CUDA_SAFECALL(cudaMemGetInfo(&free, &total));
	if(maxGPUMem < total - free) {
	    maxGPUMem = total - free;
	    userGPUMem = dataSize;
	}
}

__global__ void flush_channel() {
    /* push memory access with negative cta id to communicate the kernel is
     * completed */
    mem_access_t ma;
    ma.warp_id = -1;
    channel_dev.push(&ma, sizeof(mem_access_t));

    /* flush channel */
    channel_dev.flush();
}

void nvbit_at_cuda_event(CUcontext ctx, int is_exit, nvbit_api_cuda_t cbid,
                         const char *name, void *params, CUresult *pStatus) {
    if (skip_flag || turned_off) return;

    if(cbid == API_CUDA_cuMemAlloc_v2 && is_exit) {
        cuMemAlloc_v2_params *p = (cuMemAlloc_v2_params *)params;
        dataSize += p->bytesize;
        printf("Allocated %lu bytes of memory at %llx, total mem %lu\n", p->bytesize, *p->dptr, dataSize);
        ptrSizes[*p->dptr] = p->bytesize;
    }
    
    else if(cbid == API_CUDA_cuMemAllocManaged && is_exit) {
        cuMemAllocManaged_params *p = (cuMemAllocManaged_params *)params;
        dataSize += p->bytesize;
        printf("Allocated %lu bytes of managed memory at %llx, total mem %lu\n", p->bytesize, *p->dptr, dataSize);
        ptrSizes[*p->dptr] = p->bytesize;        
    }
    
    else if((cbid == API_CUDA_cuMemAllocHost_v2) && is_exit) {
        cuMemAllocHost_v2_params *p = (cuMemAllocHost_v2_params *)params;
        dataSize += p->bytesize;
        printf("Allocated %lu bytes of host memory at %p, total mem %lu\n", p->bytesize, *p->pp, dataSize);
        ptrSizes[(CUdeviceptr)*p->pp] = p->bytesize;        
    }
        
    else if(cbid == API_CUDA_cuMemFree_v2 && is_exit) {
        cuMemFree_v2_params *p = (cuMemFree_v2_params *)params;
        size_t size = ptrSizes[p->dptr];
        dataSize -= size;
        ptrSizes.erase(p->dptr);
        printf("Freed %llx, total mem %lu\n", p->dptr, dataSize);        
    }
    
    else if(cbid == API_CUDA_cuMemFreeHost && is_exit) {
        cuMemFreeHost_params *p = (cuMemFreeHost_params *)params;
        size_t size = ptrSizes[(CUdeviceptr)p->p];
        dataSize -= size;
        ptrSizes.erase((CUdeviceptr)p->p);
        printf("Host freed %llx, total mem %lu\n", (CUdeviceptr)p->p, dataSize); 
        
    }

    else if (cbid == API_CUDA_cuLaunchKernel_ptsz ||
        cbid == API_CUDA_cuLaunchKernel ||
        cbid == API_CUDA_cuLaunchCooperativeKernel ||
        cbid == API_CUDA_cuLaunchCooperativeKernel_ptsz) {
        cuLaunchKernel_params *p = (cuLaunchKernel_params *)params;

        if (!is_exit) {
            instrument_function_if_needed(ctx, p->f);
            nvbit_enable_instrumented(ctx, p->f, true);
                int nregs;
                CUDA_SAFECALL(
                    cuFuncGetAttribute(&nregs, CU_FUNC_ATTRIBUTE_NUM_REGS, p->f));

                int shmem_static_nbytes;
                CUDA_SAFECALL(
                    cuFuncGetAttribute(&shmem_static_nbytes,
                                       CU_FUNC_ATTRIBUTE_SHARED_SIZE_BYTES, p->f));
            printf(
                "Kernel %s - grid size %d,%d,%d - block size %d,%d,%d - nregs "
                "%d - shmem %d - cuda stream id %ld\n",
                nvbit_get_func_name(ctx, p->f), p->gridDimX, p->gridDimY,
                p->gridDimZ, p->blockDimX, p->blockDimY, p->blockDimZ, nregs,
                shmem_static_nbytes + p->sharedMemBytes, (uint64_t)p->hStream);
            if(debug_out) {
                start_time = std::chrono::high_resolution_clock::now();
            }
            skip_flag = true;
            if(started == true) {
                for(unsigned i = 0; i < TOTAL_CTRS; ++i)
                    if((check_locking || i != LOCKS) && (check_its || i != WARP_BAR))
                        CUDA_SAFECALL(cudaFree(counters[i]));
                if(md_scale > 1) {
                    CUDA_SAFECALL(cudaFree(metadata[WR_MD]));
                    CUDA_SAFECALL(cudaFree(metadata[RD_MD]));
                }
            }
            
            started = true;
            
            if(md_scale > 1) {
                CUDA_SAFECALL(cudaMallocManaged((void**)&metadata[WR_MD], sizeof(uint64_t) * roundUp(dataSize, granularity * md_scale)));
                CUDA_SAFECALL(cudaMallocManaged((void**)&metadata[RD_MD], sizeof(uint64_t) * roundUp(dataSize, granularity * md_scale)));
                mdArrayLen = roundUp(dataSize, granularity * md_scale);
            }
            
            uint64_t NBLOCKS = p->gridDimX * p->gridDimY * p->gridDimZ;
            uint64_t NWARPS  = roundUp(p->blockDimX * p->blockDimY * p->blockDimZ, WARP_SIZE) * NBLOCKS;
            
            size_t free = 0, total = 0;
            CUDA_SAFECALL(cudaMemGetInfo(&free, &total));
            
            if(managed || free < sizeof(BYTE) * (2 * NWARPS + NBLOCKS)) { 
                CUDA_SAFECALL(cudaMallocManaged((void**)&counters[BARRIER],   sizeof(BYTE) * NBLOCKS));
                CUDA_SAFECALL(cudaMallocManaged((void**)&counters[WARP_CTRS], sizeof(HWORD) * NWARPS * WARP_SIZE));
            }
            else {
                CUDA_SAFECALL(cudaMalloc((void**)&counters[BARRIER],   sizeof(BYTE) * NBLOCKS));
                CUDA_SAFECALL(cudaMalloc((void**)&counters[WARP_CTRS], sizeof(HWORD) * NWARPS * WARP_SIZE));
                free -= sizeof(BYTE) * (NBLOCKS) + sizeof(DWORD) * NWARPS;
            }            
            
            if(check_its) {
                if(managed || free < sizeof(BYTE) * NWARPS) {
                    CUDA_SAFECALL(cudaMallocManaged((void**)&counters[WARP_BAR], sizeof(BYTE) * NWARPS));
                }
                else {
                    CUDA_SAFECALL(cudaMalloc((void**)&counters[WARP_BAR], sizeof(BYTE) * NWARPS));
                    free -= sizeof(BYTE) * NWARPS;
                }                 
            }
            if(check_locking) {
                if(managed || free < sizeof(DWORD) * NWARPS * /*(lock_granularity == 0 ? 1 : */WARP_SIZE) {
                    CUDA_SAFECALL(cudaMallocManaged((void**)&counters[LOCKS], sizeof(DWORD) * NWARPS * /*(lock_granularity == 0 ? 1 : */WARP_SIZE));
                }
                else {
                    CUDA_SAFECALL(cudaMalloc((void**)&counters[LOCKS], sizeof(DWORD) * NWARPS * /*(lock_granularity == 0 ? 1 : */WARP_SIZE));
                    free -= sizeof(DWORD) * NWARPS * /*(lock_granularity == 0 ? 1 : */WARP_SIZE;
                }
            }
            
            CUDA_SAFECALL(cudaMemset(counters[BARRIER],   0, sizeof(BYTE) * NBLOCKS));
            CUDA_SAFECALL(cudaMemset(counters[WARP_CTRS], 0, sizeof(HWORD) * NWARPS * WARP_SIZE));
            if(check_its)
                CUDA_SAFECALL(cudaMemset(counters[WARP_BAR], 0, sizeof(BYTE) * NWARPS));
            if(check_locking)
                CUDA_SAFECALL(cudaMemset(counters[LOCKS], 0, sizeof(DWORD) * NWARPS * WARP_SIZE));
            uint64_t now_used = 0;
            CUDA_SAFECALL(cudaMemGetInfo(&free, &total));
            free += prev_used;
            for(auto i = ptrSizes.begin(); i != ptrSizes.end(); ++i) {
                uint64_t offset = (i->first / granularity) % mdArrayLen;
                if(free > 2 * sizeof(uint64_t) * roundUp(i->second, granularity)) {
                    // Set md to 0. If data wraps around array, split into two memsets
                    if(roundUp(i->second, granularity) + offset < mdArrayLen) {
                        CUDA_SAFECALL(cudaMemset((uint64_t*)metadata[WR_MD] + offset, 0, sizeof(uint64_t) * roundUp(i->second, granularity)));
                        CUDA_SAFECALL(cudaMemset((uint64_t*)metadata[RD_MD] + offset, 0, sizeof(uint64_t) * roundUp(i->second, granularity)));
                        now_used += 2 * sizeof(uint64_t) * roundUp(i->second, granularity);
                        if(free > 2 * sizeof(uint64_t) * roundUp(i->second, granularity))
                            free -= 2 * sizeof(uint64_t) * roundUp(i->second, granularity);
                        else
                            free = 0;
                    }
                    else {
                        // Data size exceeds array size. Just set everything to zero and leave
                        if(roundUp(i->second, granularity) >= mdArrayLen) {
                            CUDA_SAFECALL(cudaMemset((uint64_t*)metadata[WR_MD], 0, sizeof(uint64_t) * mdArrayLen));
                            CUDA_SAFECALL(cudaMemset((uint64_t*)metadata[RD_MD], 0, sizeof(uint64_t) * mdArrayLen));
                            now_used = 2 * mdArrayLen;
                            if(free > 2 * mdArrayLen)
                                free -= 2 * mdArrayLen;
                            else
                                free = 0;
                            break;
                        }
                        
                        uint64_t extra = roundUp(i->second, granularity) - (mdArrayLen - offset);
                        CUDA_SAFECALL(cudaMemset((uint64_t*)metadata[WR_MD] + offset, 0, sizeof(uint64_t) * (mdArrayLen - offset)));
                        CUDA_SAFECALL(cudaMemset((uint64_t*)metadata[RD_MD] + offset, 0, sizeof(uint64_t) * (mdArrayLen - offset)));
                        CUDA_SAFECALL(cudaMemset((uint64_t*)metadata[WR_MD], 0, sizeof(uint64_t) * extra));
                        CUDA_SAFECALL(cudaMemset((uint64_t*)metadata[RD_MD], 0, sizeof(uint64_t) * extra));
                        now_used += 2 * sizeof(uint64_t) * roundUp(i->second, granularity);
                        if(free > 2 * sizeof(uint64_t) * roundUp(i->second, granularity))
                            free -= 2 * sizeof(uint64_t) * roundUp(i->second, granularity);
                        else
                            free = 0;
                    }
                }
                else {
                    printf("Data too large, memset on CPU. Free %ld, total %ld, needed %ld, used %ld\n", free, total, 2 * sizeof(uint64_t) * roundUp(i->second, granularity), prev_used);
                    // Set md to 0. If data wraps around array, split into two memsets
                    if(roundUp(i->second, granularity) + offset < mdArrayLen) {
                        memset((uint64_t*)metadata[WR_MD] + offset, 0, sizeof(uint64_t) * roundUp(i->second, granularity));
                        memset((uint64_t*)metadata[RD_MD] + offset, 0, sizeof(uint64_t) * roundUp(i->second, granularity));
                    }
                    else {
                        // Data size exceeds array size. Just set everything to zero and leave
                        if(roundUp(i->second, granularity) >= mdArrayLen) {
                            memset((uint64_t*)metadata[WR_MD], 0, sizeof(uint64_t) * mdArrayLen);
                            memset((uint64_t*)metadata[RD_MD], 0, sizeof(uint64_t) * mdArrayLen);
                            break;
                        }
                        
                        uint64_t extra = roundUp(i->second, granularity) - (mdArrayLen - offset);
                        memset((uint64_t*)metadata[WR_MD] + offset, 0, sizeof(uint64_t) * (mdArrayLen - offset));
                        memset((uint64_t*)metadata[RD_MD] + offset, 0, sizeof(uint64_t) * (mdArrayLen - offset));
                        memset((uint64_t*)metadata[WR_MD], 0, sizeof(uint64_t) * extra);
                        memset((uint64_t*)metadata[RD_MD], 0, sizeof(uint64_t) * extra);
                    }
                }
            }
            prev_used = now_used;
            skip_flag = false;
            
            cudaDeviceSynchronize();
            cudaError_t err = cudaGetLastError();
            if(err != cudaSuccess) {
                printf("CUDA error (%d): %s\n", err, cudaGetErrorName (err));
                fflush(stdout);
                assert(false);
            }
            recv_thread_receiving = true;
            if(debug_out) {
                setup_time += (double)std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::high_resolution_clock::now() - start_time).count() / 1000.0;
                start_kernel = std::chrono::high_resolution_clock::now();
            }
        } else {
            
            if(debug_out)           
                update_rss();
            /* make sure current kernel is completed */
            cudaDeviceSynchronize();
            cudaError_t err = cudaGetLastError();
            if(err != cudaSuccess) {
                printf("CUDA error (%d): %s\n", err, cudaGetErrorName (err));
                fflush(stdout);
                assert(false);
            }
            if(debug_out) {
                kernel_time += (double)std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::high_resolution_clock::now() - start_kernel).count() / 1000.0;
                start_time = std::chrono::high_resolution_clock::now();
            }

            /* make sure we prevent re-entry on the nvbit_callback when issuing
             * the flush_channel kernel */
            skip_flag = true;

            /* issue flush of channel so we are sure all the memory accesses
             * have been pushed */
            flush_channel<<<1, 1>>>();
            cudaDeviceSynchronize();
            err = cudaGetLastError();
            if(err != cudaSuccess) {
                printf("CUDA error (%d): %s\n", err, cudaGetErrorName (err));
                fflush(stdout);
                assert(false);
            }

            /* unset the skip flag */
            skip_flag = false;

            /* wait here until the receiving thread has not finished with the
             * current kernel */
            while (recv_thread_receiving) {
                pthread_yield();
            }
            if(debug_out)
                thread_time += (double)std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::high_resolution_clock::now() - start_time).count() / 1000.0;
        }
    }
}

void *recv_thread_fun(void *) {
    char *recv_buffer = (char *)malloc(CHANNEL_SIZE);
    cudaStream_t pStream;
    bool flushed = false;
    while (recv_thread_started) {
        //if(flushed) // Timed out and wrapped around
        //    assert(false);
        auto end = std::chrono::high_resolution_clock::now();
        if(!flushed && timeout > 0 && std::chrono::duration_cast<std::chrono::seconds>(end - start).count() > timeout) {
            printf("\nKernel timed out.\n");
            fflush(stdout);
            int highestPriority;
            cudaDeviceGetStreamPriorityRange (NULL, &highestPriority );
            cudaStreamCreateWithPriority ( &pStream, cudaStreamNonBlocking, highestPriority );
            skip_flag = true;
            flush_channel<<<1, 1, 0, pStream>>>();
            flushed = true;
            skip_flag = false;
        }
        
        uint32_t num_recv_bytes = 0;
        if (recv_thread_receiving &&
            (num_recv_bytes = channel_host.recv(recv_buffer, CHANNEL_SIZE)) >
                0) {
            uint32_t num_processed_bytes = 0;
            while (num_processed_bytes < num_recv_bytes) {
                mem_access_t *ma =
                    (mem_access_t *)&recv_buffer[num_processed_bytes];

                /* when we get this cta_id_x it means the kernel has completed */
                if (ma->warp_id == -1) {
                    recv_thread_receiving = false;
                    if(flushed) // Due to timeout
                        assert(false);
                    break;
                }
                num_processed_bytes += sizeof(mem_access_t);
                
                if(id_to_opcode_map.find(ma->opcode_id) == id_to_opcode_map.end())
                    continue;
                
                printf("\n");
                switch(ma->reason) {
                    case RACE_BFENCE: printf("Race: Missing blkfence");    break;
                    case RACE_GFENCE: printf("Race: Missing gpufence");    break;
                    case RACE_STRONG: printf("Race: Missing strong op");   break;
                    case RACE_ATOMIC: printf("Race: Improper atom scope"); break;
                    case RACE_LOCK:   printf("Race: Missing lock");        break;
                    case RACE_ITS:    printf("Race: Missing warpsync");    break;
                }
                printf("\n");
                
                // Get line info and file details
                std::string p = id_to_opcode_map[ma->opcode_id];
                
                printf("%s - ", p.c_str());
                printf("(TID %lu, ", ma->warp_id);
                id_to_opcode_map.erase(ma->opcode_id);
                printf("%lx)", ma->addr);
                printf("\n");
                uint64_t md = ma->write_md;
                printf("Write: M(%lu), BShr(%lu), GShr(%lu), Atom(%lu), Scope(%lu), Str(%lu), TID(%lu), GF(%lu), BF(%lu), Bar(%lu), WBar(%lu), Locks(%lx)\n",
                    getBit(md, BIT1_MOD), getBit(md, BIT1_BSHR), getBit(md, BIT1_GSHR), getBit(md, BIT1_ATOMIC), getBit(md, BIT1_SCOPE), 
                    getBit(md, BIT_STRONG), getBits(md, BIT_TID, SZ_TID), getBits(md, BIT_GFENCE, SZ_GFENCE), getBits(md, BIT_BFENCE, SZ_BFENCE), 
                    getBits(md, BIT_BAR, SZ_BAR), getBits(md, BIT_WBAR, SZ_WBAR), getBits(md, BIT_LOCKS, SZ_LOCKS));
                
                md = ma->read_md;
                printf("Read: Tag(%lu), Str(%lu), TID(%lu), GF(%lu), BF(%lu), Bar(%lu), WBar(%lu), Locks(%lx)\n",
                    getBits(md, BIT2_TAG, SZ_TAG), getBit(md, BIT_STRONG), getBits(md, BIT_TID, SZ_TID), getBits(md, BIT_GFENCE, SZ_GFENCE), 
                    getBits(md, BIT_BFENCE, SZ_BFENCE), getBits(md, BIT_BAR, SZ_BAR), getBits(md, BIT_WBAR, SZ_WBAR), getBits(md, BIT_LOCKS, SZ_LOCKS)); 
                
                printf("OGF(%lu), OBF(%lu), OBar(%lu), Heldlock(%lu)\n", getBits(ma->extra, 0, 8), getBits(ma->extra, 8, 8), getBits(ma->extra, 16, 8), getBits(ma->extra, 24, 16));
                
                fflush(stdout);
                if(race_exit)
                    assert(false);
            }
        }
    }
    free(recv_buffer);
    return NULL;
}

void nvbit_at_ctx_init(CUcontext ctx) {
    if(!turned_off && !recv_thread_started) {
        recv_thread_started = true;
        channel_host.init(0, CHANNEL_SIZE, &channel_dev, NULL);
        pthread_create(&recv_thread, NULL, recv_thread_fun, NULL);
    }
    
    start = std::chrono::high_resolution_clock::now();
    skip_flag = true;
    cudaMemcpy(&parameters[BYTE_GRAN], &granularity, sizeof(uint32_t), cudaMemcpyHostToDevice);
    uint32_t val = ((check_locking ? MASK_CHECK_LOCKS : 0) | /*(lock_granularity ? MASK_LOCK_GRAN : 0) |*/ (check_its ? MASK_CHECK_ITS : 0));
    cudaMemcpy(&parameters[OPTIONS], &val, sizeof(uint32_t), cudaMemcpyHostToDevice);
    
    size_t free = 0, total = 0;
    CUDA_SAFECALL(cudaMemGetInfo(&free, &total));
    if(md_scale == 1) {
        if(managed) {
            CUDA_SAFECALL(cudaMallocManaged((void**)&metadata[WR_MD], sizeof(uint64_t) * roundUp(total, granularity)));
            CUDA_SAFECALL(cudaMallocManaged((void**)&metadata[RD_MD], sizeof(uint64_t) * roundUp(total, granularity)));
            mdArrayLen = roundUp(total, granularity);
        }
        else { // Redundant condition, to be removed in future.
            CUDA_SAFECALL(cudaMalloc((void**)&metadata[WR_MD], sizeof(uint64_t) * roundUp(total / 8, granularity)));
            CUDA_SAFECALL(cudaMalloc((void**)&metadata[RD_MD], sizeof(uint64_t) * roundUp(total / 8, granularity)));
            mdArrayLen = roundUp(total / 8, granularity);
        }
        cudaDeviceSynchronize();
    }
    
    skip_flag = false;
    if(debug_out) {
        init_time += (double)std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::high_resolution_clock::now() - start).count() / 1000.0;
    }
}

void nvbit_at_ctx_term(CUcontext ctx) {
    if (recv_thread_started) {
        recv_thread_started = false;
    }
    char linkname[1024] = "<unknown>";
    int len = readlink("/proc/self/exe", linkname, sizeof(linkname));
    const char* name = strrchr(linkname, '/');
    if(name == NULL) name = linkname; else name += 1;
    fflush(stdout);
    fflush(stderr);
    
    skip_flag = true;
    if(started == true) {
        for(unsigned i = 0; i < TOTAL_CTRS; ++i)
            if((check_locking || i != LOCKS) && (check_its || i != WARP_BAR))
                CUDA_SAFECALL(cudaFree(counters[i]));
        CUDA_SAFECALL(cudaFree(metadata[WR_MD]));
        CUDA_SAFECALL(cudaFree(metadata[RD_MD]));
    }
    skip_flag = false;
    if(recv_thread_started) {
        pthread_join(recv_thread, NULL);
    }
    auto end = std::chrono::high_resolution_clock::now();
    if(debug_out) {
        printf("TIME MS %s %lf %s\n", name, (double)std::chrono::duration_cast<std::chrono::microseconds>(end - start).count() / 1000.0, 
            (turned_off ? "DISABLED" : "ENABLED"));
        printf("MAXGPUMEM\t%s\t%lu\n", name, maxGPUMem);
        printf("USERGPUMEM\t%s\t%lu\n", name, userGPUMem);
        printf("\tInit\tInstrument\tThread\tSetup\tKernel\nBREAKDOWN\t%f\t%f\t%f\t%f\t%f\n", init_time, instru_time, thread_time, setup_time, kernel_time);
    }
}
