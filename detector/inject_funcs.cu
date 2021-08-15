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

#include <stdint.h>
#include <stdio.h>

// Comment to remove printfs
//#define DEBUG

#include "utils/utils.h"
#include "utils/channel.hpp"

/* contains definition of the mem_access_t structure */
#include "common.h"

__device__ int global_lock = 0;

extern "C" __device__ __noinline__ void instrument_fence(int pred, scope_t scope, uint64_t fenceId,
    uint64_t locks, uint64_t parameters) 
{
    if (!pred) {
        return;
    }
    
    unsigned mask = __activemask();
    
    /* Get actual array */
    fenceId = *(uint64_t*)fenceId;
    locks = *(uint64_t*)locks;
    
    uint64_t WARPS_PER_BLK = roundUp(blockDim.x * blockDim.y * blockDim.z, WARP_SIZE);
    // Local threadId, i.e. within a single block
    uint64_t tid = serializeId(threadIdx.x, threadIdx.y, threadIdx.z, blockDim.x, blockDim.y, blockDim.z);
    // Local warpId, i.e. within a single block
    uint64_t wid = tid / WARP_SIZE;
    // BlockId
    uint64_t bid = serializeId(blockIdx.x, blockIdx.y, blockIdx.z, gridDim.x, gridDim.y, gridDim.z);
    // Global warpId i.e. across all blocks
    uint64_t g_wid = wid + bid * WARPS_PER_BLK;
    // Global threadId i.e. across all blocks
    uint64_t g_tid = tid + bid * blockDim.x * blockDim.y * blockDim.z;
    
    tid %= WARP_SIZE;
    // (mask - 1) & mask -> Unset last bit
    // ^ mask -> Unset all bits except last bit
    unsigned selectedThread = ((mask - 1) & mask) ^ mask;
    
    // Activate locks if needed
    if(hasMask(((uint32_t*)parameters)[OPTIONS], MASK_CHECK_LOCKS)) {
        uint64_t lock_table = atomicAdd(&((ULL*)locks)[g_wid], 0);
        bool moved = false;
        if(getBit(lock_table, LKBIT_MOVED)) {// Use thread level 
            lock_table = atomicAdd(&((ULL*)locks)[g_tid], 0);
            moved = true;
        }
        if(getBits(lock_table, 0, LKBIT_MOVED) != 0) { // Skip in common case
            for(uint32_t i = 0; i < LKS_PER_THD; ++i) {
                if(scope != SCOPE_CTA || getBit(lock_table, LOCK_SIZE * i + LKBIT_SCOPE))
                    setBit(lock_table, LOCK_SIZE * i + LKBIT_ACTIVE); // Mark locks active
            }
            
            // Write back
            if(moved)
                atomicExch(&((ULL*)locks)[g_tid], lock_table);
            else if((1 << tid) & selectedThread)
                atomicExch(&((ULL*)locks)[g_wid], lock_table);
        }
    }
    
    g_tid = (g_wid << 5) | (tid & ((ONE << 5) - ONE));
    // Only last thread updates
    //if((1 << tid) & selectedThread) {
        switch(scope) {
            case SCOPE_NONE:
            case SCOPE_GPU:
            case SCOPE_SYS:
                ++(((BYTE*)fenceId)[sizeof(HWORD) * g_tid + GPU_FENCE]);
            break;
            case SCOPE_CTA:
                ++(((BYTE*)fenceId)[sizeof(HWORD) * g_tid + BLK_FENCE]);
            break;
        }
	    debug_printf("WID %lu: %s scope fence; blk: %d, dev: %d\n", g_tid, scopeToStr(scope), 
	        ((BYTE*)fenceId)[sizeof(HWORD) * g_tid + BLK_FENCE], ((BYTE*)FenceId)[sizeof(HWORD) * g_tid + GPU_FENCE]);
    //}
    // Force warp to wait until update complete
    __syncwarp(mask);
}

extern "C" __device__ __noinline__ void instrument_barrier(int pred, uint64_t barrierId) 
{
    if (!pred) {
        return;
    }
    
    /* Get actual array */
    barrierId = *(uint64_t*)barrierId;    
    
    int tid = serializeId(threadIdx.x, threadIdx.y, threadIdx.z, blockDim.x, blockDim.y, blockDim.z);
    // Have only single warp update barrierID
    if(tid < WARP_SIZE) {
        int bid = serializeId(blockIdx.x, blockIdx.y, blockIdx.z, gridDim.x, gridDim.y, gridDim.z);
        unsigned mask = __activemask();
        // (mask - 1) & mask -> Unset last bit
        // ^ mask -> Unset all bits except last bit
        unsigned selectedThread = ((mask - 1) & mask) ^ mask;
        // Only last thread updates
        if((1 << tid) & selectedThread) {
            ++(((BYTE*)barrierId)[bid]);
	        debug_printf("BID %d: Barrier; counter %d\n", bid, ((BYTE*)barrierId)[bid]);
        }
    }
    // Have other threads wait until update is received
    __syncthreads();
}

extern "C" __device__ __noinline__ void instrument_warp_bar(int pred, uint64_t warpBarrierId) 
{
    if (!pred) {
        return;
    }
    unsigned mask = __activemask();
    warpBarrierId = *(uint64_t*)warpBarrierId;
    
    uint64_t WARPS_PER_BLK = roundUp(blockDim.x * blockDim.y * blockDim.z, WARP_SIZE);
    // Local threadId, i.e. within a single block
    uint64_t tid = serializeId(threadIdx.x, threadIdx.y, threadIdx.z, blockDim.x, blockDim.y, blockDim.z);
    // Local warpId, i.e. within a single block
    uint64_t wid = tid / WARP_SIZE;
    // BlockId
    uint64_t bid = serializeId(blockIdx.x, blockIdx.y, blockIdx.z, gridDim.x, gridDim.y, gridDim.z);
    // Global warpId i.e. across all blocks
    uint64_t g_wid = wid + bid * WARPS_PER_BLK;
    
    tid %= WARP_SIZE;    
    // (mask - 1) & mask -> Unset last bit
    // ^ mask -> Unset all bits except last bit
    unsigned selectedThread = ((mask - 1) & mask) ^ mask;
    // Only last thread updates
    if((1 << tid) & selectedThread) {
        ++(((BYTE*)warpBarrierId)[g_wid]);
	    debug_printf("WID %lu: Warp barrier; counter %d\n", g_wid,
	        ((BYTE*)warpBarrierId)[g_wid]);
    }
    __syncwarp(mask);
}

__device__ __inline__ void print_instr(uint32_t op_mask, scope_t scope, uint64_t addr, uint64_t offset)
{
    uint64_t WARPS_PER_BLK = roundUp(blockDim.x * blockDim.y * blockDim.z, WARP_SIZE);
    // Local threadId, i.e. within a single block
    uint64_t tid = serializeId(threadIdx.x, threadIdx.y, threadIdx.z, blockDim.x, blockDim.y, blockDim.z);
    // Local warpId, i.e. within a single block
    uint64_t wid = tid / WARP_SIZE;
    // BlockId
    uint64_t bid = serializeId(blockIdx.x, blockIdx.y, blockIdx.z, gridDim.x, gridDim.y, gridDim.z);
    // Global warpId i.e. across all blocks
    uint64_t g_wid = wid + bid * WARPS_PER_BLK;
    tid %= WARP_SIZE;
    unsigned mask = __activemask();
    // (mask - 1) & mask -> Unset last bit
    // ^ mask -> Unset all bits except last bit
    unsigned selectedThread = ((mask - 1) & mask) ^ mask;
    // Only last thread updates
    if((1 << tid) & selectedThread) {
        if(hasMask(op_mask, MASK_ATOMIC)) {
            debug_printf("WID %lu: %s scope atomic at %lx, offset %lx\n", g_wid, scopeToStr(scope), addr, offset);
        }
        
        else if(hasMask(op_mask, MASK_LOAD)) {
            debug_printf("WID %lu: %s %s scope load at %lx, offset %lx\n", g_wid, 
                (hasMask(op_mask, MASK_STRONG) ? "Strong" : "Weak"), scopeToStr(scope), addr, offset);
        }
        
        else if(hasMask(op_mask, MASK_STORE)) {
            debug_printf("WID %lu: %s %s scope store at %lx, offset %lx\n", g_wid, 
                (hasMask(op_mask, MASK_STRONG) ? "Strong" : "Weak"), scopeToStr(scope), addr, offset);
        }
    }
}

__device__ __inline__ void print_md(uint64_t md, uint64_t read_md, uint64_t g_wid, uint64_t filter, uint64_t offset, BYTE GF, BYTE BF, BYTE OWB)
{
    unsigned tid = serializeId(threadIdx.x, threadIdx.y, threadIdx.z, blockDim.x, blockDim.y, blockDim.z);
    tid %= WARP_SIZE;
    unsigned mask = __activemask();
    // (mask - 1) & mask -> Unset last bit
    // ^ mask -> Unset all bits except last bit
    unsigned selectedThread = __ffs(mask) - 1;
    // Only last thread updates
    if(tid == selectedThread)
        debug_printf("WID %lu (%x): (%lx) V(%lu), M(%lu), GS(%lu), BS(%lu), Atom(%lu), Scope(%lu), Str(%lu), TID_W(%lu), TID_R(%lu), GF(%lu), BF(%lu), Bar(%lu), WBar(%lu), Locks(%lx); Locks held(%lx), OWGF(%d), OWBF(%d), OBAR(%d)\n", 
            g_wid, mask, offset, getBit(md, BIT1_VALID), getBit(md, BIT1_MOD), getBit(md, BIT1_GSHR), getBit(md, BIT1_BSHR), getBit(md, BIT1_ATOMIC), getBit(md, BIT1_SCOPE), 
            getBit(md, BIT_STRONG), getBits(md, BIT_TID, SZ_TID), getBits(read_md, BIT_TID, SZ_TID), getBits(md, BIT_GFENCE, SZ_GFENCE), getBits(md, BIT_BFENCE, SZ_BFENCE), 
            getBits(md, BIT_BAR, SZ_BAR), getBits(md, BIT_WBAR, SZ_WBAR), (getBits(md, BIT_LOCKS, SZ_LOCKS) << 8) | getBits(read_md, BIT_LOCKS, SZ_LOCKS), filter, GF, BF, OWB); 
}

__device__ __inline__ void setup_lock(void *locks, uint32_t op_mask, uint64_t addr, scope_t scope, uint64_t parameters, uint32_t threadMask)
{
    // Do we need to check locks?
    if(!hasMask(((uint32_t*)parameters)[OPTIONS], MASK_CHECK_LOCKS)) return;
    // Check if atomic
    if(!hasMask(op_mask, MASK_ATOMIC)) return;
    // Check if CAS or Exch
    if(!hasMask(op_mask, MASK_CAS) && !hasMask(op_mask, MASK_EXCH)) return;
    
    unsigned mask = __activemask();

    uint64_t WARPS_PER_BLK = roundUp(blockDim.x * blockDim.y * blockDim.z, WARP_SIZE);
    // Local threadId, i.e. within a single block
    uint64_t tid = serializeId(threadIdx.x, threadIdx.y, threadIdx.z, blockDim.x, blockDim.y, blockDim.z);
    // BlockId
    uint64_t bid = serializeId(blockIdx.x, blockIdx.y, blockIdx.z, gridDim.x, gridDim.y, gridDim.z);
    // Local warpId, i.e. within a single block
    uint64_t wid = tid / WARP_SIZE;
    // Global warpId i.e. across all blocks
    uint64_t g_wid = wid + bid * WARPS_PER_BLK;
    // Global threadId i.e. across all blocks
    uint64_t g_tid = tid + bid * blockDim.x * blockDim.y * blockDim.z;
    
    if(hasMask(op_mask, MASK_CAS)) {
    
        uint64_t lock_table = atomicAdd(&((ULL*)locks)[g_wid], 0);
    
        bool moved = false;

        // More than one thread performing op
        if((threadMask - 1) & threadMask) {
            lock_table = atomicAdd(&((ULL*)locks)[g_tid], 0);
            moved = true;
            // Dynamically switch from warp level to thread level
            if(!getBit(lock_table, LKBIT_MOVED)) {
                lock_table = 0; // Reset table for first use
                setBit(lock_table, LKBIT_MOVED);
                // Set moved for warp-level table
                atomicOr(&((ULL*)locks)[g_wid], (ONE << (uint64_t)LKBIT_MOVED));
            }
        }

        else if(getBit(lock_table, LKBIT_MOVED)) { // Use thread level
            lock_table = atomicAdd(&((ULL*)locks)[g_tid], 0);
            moved = true;
        }

        // Get lower order bits of address. Atomics use
        // 4/8-byte aligned variables so ignore lower 2 bits
        uint64_t addr_bits = getBits(addr, 2, LKDATA_SIZE);
        // See if lock already exists in table
        bool success = false;
        for(uint32_t i = 0; i < LKS_PER_THD; ++i) {
            if(getBits(lock_table, LOCK_SIZE * i, LKDATA_SIZE) == addr_bits) { // Same lock
                setBit(lock_table,  LOCK_SIZE * i + LKBIT_ACTIVE, 0); // Mark inactive
                setBit(lock_table,  LOCK_SIZE * i + LKBIT_VALID, 1); // Mark valid
                setBit(lock_table,  LOCK_SIZE * i + LKBIT_SCOPE, scope == SCOPE_CTA); // Set scope
                success = true;
                break;
            }
        }
        // Find inactive slot and insert
        if(!success) {
            for(uint32_t i = 0; i < LKS_PER_THD; ++i) {
                if(!getBit(lock_table,  LOCK_SIZE * i + LKBIT_VALID)) { // Not valid
                    setBits(lock_table, LOCK_SIZE * i,  LKDATA_SIZE, addr_bits);
                    setBit(lock_table,  LOCK_SIZE * i + LKBIT_ACTIVE, 0); // Mark inactive
                    setBit(lock_table,  LOCK_SIZE * i + LKBIT_VALID, 1); // Mark valid
                    setBit(lock_table,  LOCK_SIZE * i + LKBIT_SCOPE, scope == SCOPE_CTA); // Set scope
                    success = true;
                    break;
                }
            }
        }
        if(!success) {
            // Replace arbitrary lock
            uint32_t i = addr_bits % LKS_PER_THD;
            setBits(lock_table, LOCK_SIZE * i,  LKDATA_SIZE, addr_bits);
            setBit(lock_table,  LOCK_SIZE * i + LKBIT_ACTIVE, 0); // Mark inactive
            setBit(lock_table,  LOCK_SIZE * i + LKBIT_VALID, 1); // Mark valid
            setBit(lock_table,  LOCK_SIZE * i + LKBIT_SCOPE, scope == SCOPE_CTA); // Set scope
            success = true;
        }
        
        tid %= WARP_SIZE;
        // (mask - 1) & mask -> Unset last bit
        // ^ mask -> Unset all bits except last bit
        unsigned selectedThread = ((mask - 1) & mask) ^ mask;
        // Write back
        if(moved)
            atomicExch(&((ULL*)locks)[g_tid], lock_table);
        else if((1 << tid) & selectedThread)
            atomicExch(&((ULL*)locks)[g_wid], lock_table);
    }
    else if(hasMask(op_mask, MASK_EXCH)) {
        //debug_printf("WID %lu: EXCH on %lx\n", g_wid, addr);
        uint64_t lock_table = atomicAdd(&((ULL*)locks)[g_wid], 0);
    
        bool moved = false;
        if(getBit(lock_table, LKBIT_MOVED)) {// Use thread level 
            lock_table = atomicAdd(&((ULL*)locks)[g_tid], 0);
            moved = true;
        }

        // Get lower order bits of address. Atomics use
        // 4/8-byte aligned variables so ignore lower 2 bits
        uint64_t addr_bits = getBits(addr, 2, LKDATA_SIZE);
        for(uint32_t i = 0; i < LKS_PER_THD; ++i) {
            if(getBits(lock_table, LOCK_SIZE * i, LKDATA_SIZE) == addr_bits && 
                (scope != SCOPE_CTA || getBit(lock_table, LOCK_SIZE * i + LKBIT_SCOPE)))
                setBit(lock_table, LOCK_SIZE * i + LKBIT_VALID, 0); // Mark matching locks invalid
        }
        
        tid %= WARP_SIZE;
        // (mask - 1) & mask -> Unset last bit
        // ^ mask -> Unset all bits except last bit
        unsigned selectedThread = ((mask - 1) & mask) ^ mask;
        // Write back
        if(moved)
            atomicExch(&((ULL*)locks)[g_tid], lock_table);
        else if((1 << tid) & selectedThread)
            atomicExch(&((ULL*)locks)[g_wid], lock_table);
    }
}

__device__ __inline__ uint64_t get_bloom_filter(void *locks, uint64_t parameters)
{
    if(!hasMask(((uint32_t*)parameters)[OPTIONS], MASK_CHECK_LOCKS)) return 0;
    
    uint64_t WARPS_PER_BLK = roundUp(blockDim.x * blockDim.y * blockDim.z, WARP_SIZE);
    // Local threadId, i.e. within a single block
    uint64_t tid = serializeId(threadIdx.x, threadIdx.y, threadIdx.z, blockDim.x, blockDim.y, blockDim.z);
    // BlockId
    uint64_t bid = serializeId(blockIdx.x, blockIdx.y, blockIdx.z, gridDim.x, gridDim.y, gridDim.z);
    // Local warpId, i.e. within a single block
    uint64_t wid = tid / WARP_SIZE;
    // Global warpId i.e. across all blocks
    uint64_t g_wid = wid + bid * WARPS_PER_BLK;
    // Global threadId i.e. across all blocks
    uint64_t g_tid = tid + bid * blockDim.x * blockDim.y * blockDim.z;
    
    uint64_t lock_table = atomicAdd(&((ULL*)locks)[g_wid], 0);
    if(getBit(lock_table, LKBIT_MOVED)) {// Use thread level 
        lock_table = atomicAdd(&((ULL*)locks)[g_tid], 0);
    }
    
    if(getBits(lock_table, 0, LKBIT_MOVED) == 0) return 0;
    
    uint64_t filter = 0;
    for(int i = 0; i < LKS_PER_THD; ++i) {
        // If valid and active
        if(getBit(lock_table, i * LOCK_SIZE + LKBIT_VALID) && 
           getBit(lock_table, i * LOCK_SIZE + LKBIT_ACTIVE)) {
            filter |= (ONE << getBits(lock_table, i * LOCK_SIZE, 3));
            filter |= (ONE << ((uint64_t)3 + getBits(lock_table, i * LOCK_SIZE + 3, 3)));
        }
    }
    return filter;
}

__device__ __inline__ void set_bloom_filter(uint64_t &write_md, uint64_t &read_md, void *locks, uint64_t parameters)
{
    uint64_t filter = get_bloom_filter(locks, parameters);
    filter &= (getBits(write_md, BIT_LOCKS, SZ_LOCKS) << 8) | getBits(read_md, BIT_LOCKS, SZ_LOCKS);
    setBits(write_md, BIT_LOCKS, SZ_LOCKS, (filter >> 8));
    setBits(read_md,  BIT_LOCKS, SZ_LOCKS, filter);
}

__device__ __inline__ void setup_metadata(uint64_t &write_md, uint64_t &read_md, void **counters, uint32_t op_mask, scope_t scope, uint64_t parameters)
{
    uint64_t WARPS_PER_BLK = roundUp(blockDim.x * blockDim.y * blockDim.z, WARP_SIZE);
    // Local threadId, i.e. within a single block
    uint64_t tid = serializeId(threadIdx.x, threadIdx.y, threadIdx.z, blockDim.x, blockDim.y, blockDim.z);
    // Local warpId, i.e. within a single block
    uint64_t wid = tid / WARP_SIZE;
    // BlockId
    uint64_t bid = serializeId(blockIdx.x, blockIdx.y, blockIdx.z, gridDim.x, gridDim.y, gridDim.z);
    // Global warpId i.e. across all blocks
    uint64_t g_wid = wid + bid * WARPS_PER_BLK;
    // Global threadId, aligned to warp size
    uint64_t g_tid = (g_wid << 5) | (tid & ((ONE << 5) - ONE));
    
    BYTE barrier   = ((BYTE*)(counters[BARRIER]))  [bid];
    HWORD warp_ctrs = ((HWORD*)(counters[WARP_CTRS]))[g_tid];
    BYTE gpu_fence = getBits(warp_ctrs, GPU_FENCE * SZ_CTR, SZ_CTR);
    BYTE blk_fence = getBits(warp_ctrs, BLK_FENCE * SZ_CTR, SZ_CTR);
    BYTE warp_bar;
    if(hasMask(((uint32_t*)parameters)[OPTIONS], MASK_CHECK_ITS))
        warp_bar  = ((BYTE*)(counters[WARP_BAR]))[g_wid];
    
    setBit (write_md, BIT1_ATOMIC, hasMask(op_mask, MASK_ATOMIC));
    setBit (write_md, BIT1_SCOPE,  scope == SCOPE_CTA);
    // On store set last writer
    if(hasMask(op_mask, MASK_STORE)) {
        setBit (write_md, BIT1_MOD,    1);
        //setBit (write_md, BIT_STRONG,  hasMask(op_mask, MASK_STRONG));
        setBits(write_md, BIT_TID,     SZ_TID,    g_tid);
        setBits(write_md, BIT_GFENCE,  SZ_GFENCE, gpu_fence);
        setBits(write_md, BIT_BFENCE,  SZ_BFENCE, blk_fence);
        setBits(write_md, BIT_BAR,     SZ_BAR,    barrier);
        if(hasMask(((uint32_t*)parameters)[OPTIONS], MASK_CHECK_ITS)) {
            setBits(write_md, BIT_WBAR, SZ_WBAR, warp_bar);
        }
    }
    // Set last accessor
    //setBit (read_md, BIT_STRONG, hasMask(op_mask, MASK_STRONG));
    setBits(read_md, BIT_TID,    SZ_TID,    g_tid);
    setBits(read_md, BIT_GFENCE, SZ_GFENCE, gpu_fence);
    setBits(read_md, BIT_BFENCE, SZ_BFENCE, blk_fence);
    setBits(read_md, BIT_BAR,    SZ_BAR,    barrier);
    if(hasMask(((uint32_t*)parameters)[OPTIONS], MASK_CHECK_ITS)) {
        setBits(read_md, BIT_WBAR, SZ_WBAR, warp_bar);
    }
}

/************************************************************************************************************
 *  CONDITIONS FOR SAFE ACCESS
 *  (a) First access   - md.Modified && md.BlkShared && md.DevShared
 *  (b) Program order  - md.WarpID == WarpID && md.BlockID == BlockID && !md.BlkShared && !md.DevShared
 *  (c) Barrier        - BlockID == md.BlockID && BarrierID != md.BarrierID && !md.DevShared
 *  
 *  CONDITIONS FOR RACEY ACCESS
 *  (a) Missing blkfence  - md.Modified && md.BlockID == BlockID && md.BlkFenceID == fFile.BlkFenceID 
 *                          && md.DevFenceID == fFile.DevFenceID
 *  (b) Missing devfence  - md.Modified && md.BlockID != BlockID && md.DevFenceID == fFile.DevFenceID
 *  (c) Not strong access - !md.Strong OR !Strong
 *  (d) Scoped atomic     - md.IsAtom && md.Scope == BLOCK && md.BlockID != BlockID
 *  (e) Missing lock      - intersect_locks().empty()
 ***********************************************************************************************************/

__device__ __inline__ uint32_t do_racecheck(uint64_t &write_md, uint64_t &read_md, uint64_t offset, void **counters, 
    uint32_t op_mask, scope_t scope, uint64_t &extra, uint64_t parameters, unsigned threadMask)
{
    uint64_t WARPS_PER_BLK = roundUp(blockDim.x * blockDim.y * blockDim.z, WARP_SIZE);
    // Local threadId, i.e. within a single block
    uint64_t tid = serializeId(threadIdx.x, threadIdx.y, threadIdx.z, blockDim.x, blockDim.y, blockDim.z);
    // Local warpId, i.e. within a single block
    uint64_t wid = tid / WARP_SIZE;
    // BlockId
    uint64_t bid = serializeId(blockIdx.x, blockIdx.y, blockIdx.z, gridDim.x, gridDim.y, gridDim.z);
    // Global warpId i.e. across all blocks
    uint64_t g_wid = wid + bid * WARPS_PER_BLK;
    // Global threadId, aligned to warp size
    uint64_t g_tid = (g_wid << 5) | (tid & ((ONE << 5) - ONE));
    
    BYTE barrier  = ((BYTE*) (counters[BARRIER]))  [bid];
    void *locks   = ((void**)(counters[LOCKS]));
    uint64_t filter = get_bloom_filter(locks, parameters);
    
    /* CONDITIONS FOR SAFE ACCESS */
    uint64_t *md;
    // Check if races with last access on write
    if(hasMask(op_mask, MASK_STORE))
        md = &read_md;
    // Check if races with last write on read
    else
        md = &write_md;

    bool SAME_BLK = (getBits(*md, BIT_WID, SZ_WID) / WARPS_PER_BLK == getBits(g_wid, 0, SZ_WID) / WARPS_PER_BLK);
    bool SAME_WRITE_BLK = (getBits(write_md, BIT_WID, SZ_WID) / WARPS_PER_BLK == getBits(g_wid, 0, SZ_WID) / WARPS_PER_BLK);
    bool SAME_READ_BLK = (getBits(read_md, BIT_WID, SZ_WID) / WARPS_PER_BLK == getBits(g_wid, 0, SZ_WID) / WARPS_PER_BLK);
    
    uint64_t other_warp = getBits(*md, BIT_WID, SZ_WID);
    uint64_t other_thread = getBits(*md, BIT_TID, SZ_TID);
    // Not first access. Get counters of other accessor
    HWORD warp_ctrs = ((HWORD*)(counters[WARP_CTRS]))[other_thread];
    uint64_t gpu_fence = getBits(warp_ctrs, GPU_FENCE * SZ_CTR, SZ_CTR);
    uint64_t blk_fence = getBits(warp_ctrs, BLK_FENCE * SZ_CTR, SZ_CTR);
    BYTE warp_bar;
    if(hasMask(((uint32_t*)parameters)[OPTIONS], MASK_CHECK_ITS))
        warp_bar  = ((BYTE*)(counters[WARP_BAR]))[other_warp];
    setBits(extra, 0, 8, getBits(gpu_fence, 0, SZ_GFENCE));
    setBits(extra, 8, 8, getBits(blk_fence, 0, SZ_GFENCE));
    setBits(extra, 2 * 8, 8, getBits(barrier, 0, SZ_GFENCE));
    setBits(extra, 3 * 8, 16, filter);
    print_md(write_md, read_md, g_wid, filter, offset, gpu_fence, blk_fence, warp_bar);
    
    // First access, safe
    if(!getBit(write_md, BIT1_VALID)) {
        //debug_printf("WID %lu: First access to %lx, safe\n", g_wid, offset);
        write_md = 0;
        read_md = 0;
        setBit(write_md, BIT1_VALID);
        setBits(write_md, BIT_LOCKS, SZ_LOCKS, (filter >> 8)); // Setup locks
        setBits(read_md,  BIT_LOCKS, SZ_LOCKS, filter); // Setup locks
        return NO_RACE;
    }
    
    // Program order, safe
    if(getBits(*md, BIT_WID, SZ_WID) == getBits(g_wid, 0, SZ_WID) 
        && (!hasMask(op_mask, MASK_STORE) || (!getBit(write_md, BIT1_GSHR) && !getBit(write_md, BIT1_BSHR)))) {
        // Check for ITS
        if(hasMask(((uint32_t*)parameters)[OPTIONS], MASK_CHECK_ITS)) {
            // Same thread, or currently in sync with thread, or synchronized at some point
            if(getBits(*md, BIT_TID, SZ_TID) == getBits(g_tid, 0, SZ_TID) || 
                ((ONE << getBits(*md, BIT_TID, 5)) & threadMask) || 
                (getBits(warp_bar, 0, SZ_WBAR) != getBits(*md, BIT_WBAR, SZ_WBAR)))
            {    
                if(SAME_BLK && getBits(*md, BIT_BAR, SZ_BAR) == barrier)           
                    set_bloom_filter(write_md, read_md, ((void**)counters)[LOCKS], parameters);
                else {
                    setBits(write_md, BIT_LOCKS, SZ_LOCKS, (filter >> 8));
                    setBits(read_md,  BIT_LOCKS, SZ_LOCKS, filter);
                }
                return NO_RACE;
            }
        }
        else {    
            if(SAME_BLK && getBits(*md, BIT_BAR, SZ_BAR) == getBits(barrier, BIT_BAR, SZ_BAR))           
                set_bloom_filter(write_md, read_md, ((void**)counters)[LOCKS], parameters);
            else {
                setBits(write_md, BIT_LOCKS, SZ_LOCKS, (filter >> 8));
                setBits(read_md,  BIT_LOCKS, SZ_LOCKS, filter);
            }
            return NO_RACE;
        }            
    }
    // Barrier, safe
    if(SAME_BLK && getBits(*md, BIT_BAR, SZ_BAR) != barrier && !getBit(write_md, BIT1_GSHR)) {
        //debug_printf("WID %lu: Barrier to %lx, safe\n", g_wid, offset);
        setBit(write_md,  BIT1_BSHR, 0);
        setBits(write_md, BIT_LOCKS, SZ_LOCKS, (filter >> 8));
        setBits(read_md,  BIT_LOCKS, SZ_LOCKS, filter);
        return NO_RACE;
    }
    
    // Appropriately scoped atomic, safe
    if(getBit(write_md, BIT1_ATOMIC) && hasMask(op_mask, MASK_ATOMIC) && 
        (!getBit(write_md, BIT1_SCOPE) || SAME_WRITE_BLK)) {
        //debug_printf("WID %lu: %s scoped atomic to %lx, safe\n", g_wid, scopeToStr(scope), offset);
        set_bloom_filter(write_md, read_md, ((void**)counters)[LOCKS], parameters);  
        return NO_RACE;
    }
    
    bool MODIFIED = hasMask(op_mask, MASK_STORE) || getBit(write_md, BIT1_MOD);
    /* CONDITIONS FOR RACEY ACCESS */
    if(MODIFIED) {
        // Improperly scoped atomic, race
        if(getBit(write_md, BIT1_ATOMIC) && getBit(write_md, BIT1_SCOPE) && !SAME_WRITE_BLK) {
            //print_md(write_md, read_md, g_wid, filter, offset, gpu_fence, blk_fence);
            debug_printf("WID %lu: improperly scoped atomic for %lx, race\n", g_wid, offset);
            // Set bits appropriately
            setBit(write_md, BIT1_MOD,  hasMask(op_mask, MASK_STORE));
            setBit(write_md, BIT1_GSHR, 0); // Reset bit for next detection
            setBit(write_md, BIT1_BSHR, 0); // Reset bit for next detection
            setBits(write_md, BIT_LOCKS, SZ_LOCKS, (filter >> 8));
            setBits(read_md,  BIT_LOCKS, SZ_LOCKS, filter);
            return RACE_ATOMIC;
        }
        
        if(hasMask(((uint32_t*)parameters)[OPTIONS], MASK_CHECK_ITS) && 
            getBits(*md, BIT_WID, SZ_WID) == getBits(g_wid, 0, SZ_WID) && 
            getBits(*md, BIT_GFENCE, SZ_GFENCE) == getBits(gpu_fence, 0, SZ_GFENCE) &&
            getBits(*md, BIT_BFENCE, SZ_BFENCE) == getBits(blk_fence, 0, SZ_BFENCE) && 
            !getBit(write_md, BIT1_BSHR) && !getBit(write_md, BIT1_GSHR)) {
            //print_md(write_md, read_md, g_wid, filter, offset, gpu_fence, blk_fence);
            debug_printf("WID %lu: missing warpsync for %lx, race\n", g_wid, offset);
            // Set bits appropriately
            setBit(write_md, BIT1_MOD,  hasMask(op_mask, MASK_STORE));
            setBit(write_md, BIT1_GSHR, 0); // Reset bit for next detection
            setBit(write_md, BIT1_BSHR, 0); // Reset bit for next detection
            setBits(write_md, BIT_LOCKS, SZ_LOCKS, (filter >> 8));
            setBits(read_md,  BIT_LOCKS, SZ_LOCKS, filter);
            return RACE_ITS;
        }
        
        // Missing blkFence, race
        if(SAME_BLK && getBits(*md, BIT_GFENCE, SZ_GFENCE) == getBits(gpu_fence, 0, SZ_GFENCE) &&
            getBits(*md, BIT_BFENCE, SZ_BFENCE) == getBits(blk_fence, 0, SZ_BFENCE)
            && !getBit(write_md, BIT1_GSHR)) {
            //print_md(write_md, read_md, g_wid, filter, offset, gpu_fence, blk_fence);
            debug_printf("WID %lu: missing blkfence for %lx; OW=%lu, race\n", g_wid, offset, other_warp);
            // Set bits appropriately
            setBit(write_md, BIT1_MOD,  hasMask(op_mask, MASK_STORE));
            setBit(write_md, BIT1_GSHR, 0); // Reset bit for next detection
            setBit(write_md, BIT1_BSHR, 0); // Reset bit for next detection
            setBits(write_md, BIT_LOCKS, SZ_LOCKS, (filter >> 8));
            setBits(read_md,  BIT_LOCKS, SZ_LOCKS, filter);
            return RACE_BFENCE;
        }
        // Missing gpufence, race
        else if(!SAME_BLK && getBits(*md, BIT_GFENCE, SZ_GFENCE) == getBits(gpu_fence, 0, SZ_GFENCE)) {
            //print_md(write_md, read_md, g_wid, filter, offset, gpu_fence, blk_fence);
            debug_printf("WID %lu: missing gpufence for %lx; OW=%lu, race\n", g_wid, offset, other_warp);
            // Set bits appropriately
            setBit(write_md, BIT1_MOD,  hasMask(op_mask, MASK_STORE));
            setBit(write_md, BIT1_GSHR, 0); // Reset bit for next detection
            setBit(write_md, BIT1_BSHR, 0); // Reset bit for next detection
            setBits(write_md, BIT_LOCKS, SZ_LOCKS, (filter >> 8));
            setBits(read_md,  BIT_LOCKS, SZ_LOCKS, filter);
            return RACE_GFENCE;    
        }
        // Missing strong ops, race
/*        else if(!getBit(*md, BIT_STRONG) || !hasMask(op_mask, MASK_STRONG)) {
            //print_md(write_md, read_md, g_wid, filter, offset, gpu_fence, blk_fence);
            debug_printf("WID %lu: missing strong op for %lx, race\n", g_wid, offset);
            // Set bits appropriately
            setBit(write_md, BIT1_MOD,  hasMask(op_mask, MASK_STORE));
            setBit(write_md, BIT1_GSHR, 0); // Reset bit for next detection
            setBit(write_md, BIT1_BSHR, 0); // Reset bit for next detection
            setBits(write_md, BIT_LOCKS, SZ_LOCKS, (filter >> 8));
            setBits(read_md,  BIT_LOCKS, SZ_LOCKS, filter);
            return RACE_STRONG;
        }*/
        
        // Missing locks
        uint64_t md_filter = (getBits(write_md, BIT_LOCKS, SZ_LOCKS) << 8) | getBits(read_md, BIT_LOCKS, SZ_LOCKS);
        if(hasMask(((uint32_t*)parameters)[OPTIONS], MASK_CHECK_LOCKS) &&
            (md_filter != 0 || filter != 0) && (md_filter & filter) == 0) {
            
            //print_md(write_md, read_md, g_wid, filter, offset, gpu_fence, blk_fence);
            debug_printf("WID %lu: missing lock for %lx, race\n", g_wid, offset);
            // Set bits appropriately
            setBit(write_md, BIT1_MOD,  hasMask(op_mask, MASK_STORE));
            setBit(write_md, BIT1_GSHR, 0); // Reset bit for next detection
            setBit(write_md, BIT1_BSHR, 0); // Reset bit for next detection
            setBits(write_md, BIT_LOCKS, SZ_LOCKS, (filter >> 8));
            setBits(read_md,  BIT_LOCKS, SZ_LOCKS, filter);
            return RACE_LOCK;        
        }        
    }
    
    uint64_t md_filter = (getBits(write_md, BIT_LOCKS, SZ_LOCKS) << 8) | getBits(read_md, BIT_LOCKS, SZ_LOCKS);
    if((md_filter != 0 || filter != 0) && (md_filter & filter) != 0) {
        //print_md(write_md, read_md, g_wid, filter, offset, gpu_fence, blk_fence);
        //debug_printf("WID %lu: properly locked for %lx\n", g_wid, offset);
        // Set bits appropriately
        set_bloom_filter(write_md, read_md, ((void**)counters)[LOCKS], parameters);  
        return NO_RACE;        
    }
    
    //debug_printf("WID %lu: No bad for %lx\n", g_wid, offset);
    // If modified, set not shared
    if(hasMask(op_mask, MASK_STORE)) {
        setBit(write_md, BIT1_GSHR, 0);
        setBit(write_md, BIT1_BSHR, 0);
    } else if (getBits(read_md, BIT_GFENCE, SZ_GFENCE) != getBits(gpu_fence, 0, SZ_GFENCE)) {
        setBit(write_md, BIT1_BSHR, 0);
        setBit(write_md, BIT1_GSHR, 0);
    } else if (SAME_READ_BLK && getBits(read_md, BIT_BFENCE, SZ_BFENCE) != getBits(blk_fence, 0, SZ_BFENCE)) {
        setBit(write_md, BIT1_BSHR, 0);
    } else if(getBits(write_md, BIT_WID, SZ_WID) / WARPS_PER_BLK != getBits(read_md, BIT_WID, SZ_WID) / WARPS_PER_BLK) {
        // Else if someone else has read set appropriate shared
        setBit(write_md, BIT1_GSHR, !SAME_READ_BLK || getBit(write_md, BIT1_GSHR)); // Set bit appropriately
        setBit(write_md, BIT1_BSHR, SAME_READ_BLK && !getBit(write_md, BIT1_GSHR)); // Reset bit for next detection
    }
    set_bloom_filter(write_md, read_md, ((void**)counters)[LOCKS], parameters);
    return NO_RACE;
}

extern "C" __device__ __noinline__ void instrument_mem(int pred, int opcode_id,
        uint64_t addr, scope_t scope, uint32_t op_mask, volatile uint64_t metadata,
        uint64_t addrStart, uint64_t mdArrayLen, uint64_t counters, uint64_t pchannel_dev, uint64_t parameters, int dataSize) 
{
    if (!pred)
        return;

    // BlockId
    unsigned mask = __activemask();
    
    // Perform contention optimizations?
    bool cont_opt = hasMask(((uint32_t*)parameters)[OPTIONS], MASK_CONTENT_OPT);
    
    uint64_t bid = serializeId(blockIdx.x, blockIdx.y, blockIdx.z, gridDim.x, gridDim.y, gridDim.z);

    if(scope == SCOPE_CTA) {
        setup_lock(((void**)counters)[LOCKS], op_mask, addr ^ (bid << 2), scope, parameters, mask); // Acquire block-scoped lock
    }
    else {
        setup_lock(((void**)counters)[LOCKS], op_mask, addr, scope, parameters, mask); // Acquire global lock
        setup_lock(((void**)counters)[LOCKS], op_mask, addr ^ (bid << 2), scope, parameters, mask); // Acquire block-scoped lock
    }
    
    /* Get actual arrays */
    mdArrayLen  = *(uint64_t*)mdArrayLen;
    
    // Check if address belongs to global memory using PTX
    int is_global_mem;
    asm (".reg .pred p;\
        isspacep.global  p, %1;\
        selp.u32 %0,1,0,p;\
        ":"=r"(is_global_mem): "l"(addr));
        
    if(is_global_mem) {
        uint64_t internalOffset = 0;
		do{
		    uint64_t dataOffset = ((addr + internalOffset) / (uint64_t)((uint32_t*)parameters)[BYTE_GRAN]);
		    uint64_t mdOffset = dataOffset % mdArrayLen;
#ifdef DEBUG
		    print_instr(op_mask, scope, addr, mdOffset);
#endif
		    uint64_t tid = serializeId(threadIdx.x, threadIdx.y, threadIdx.z, blockDim.x, blockDim.y, blockDim.z);
		    tid %= WARP_SIZE;
		    // If all threads are reading/atoming same location
		    // Have only one thread do race detection
		    unsigned mask2 = __activemask();
		    uint64_t oth_addr = __shfl_sync(mask2, addr, __ffs(mask2) - 1);
		    if(oth_addr != addr || !hasMask(op_mask, MASK_LOAD) || !cont_opt || (tid == __ffs(mask2) - 1)) {
		        uint32_t detected_race = NO_RACE;
		        DWORD race_read_md;
		        DWORD race_write_md;
		        DWORD extra = 0;
		        bool complete = false;
		        const unsigned WARPS = (blockDim.x * min(gridDim.x, 100)) / WARP_SIZE;
		        const unsigned BASE_DELAY = 100;
		        const unsigned MAX_DELAY = max(BASE_DELAY, WARPS * BASE_DELAY / 40);
		        unsigned delay = (cont_opt ? BASE_DELAY : 0);
		        do {
		            // -1 indicates unused, -2 indicates in-use
		            const DWORD reserved_data = (DWORD)-2;
		            DWORD read_md = atomicAdd(&((ULL**)metadata)[RD_MD][mdOffset], 0);
		            // Already reserved, can possibly do a delay here?
		            if(read_md == reserved_data) {
		                if(delay) {
		                    csleep(delay);
		                    delay *= 2;
		                    delay = min(delay, MAX_DELAY);
		                }
		                continue;
		            }
		            // Try to swap
		            if(atomicCAS(&((ULL**)metadata)[RD_MD][mdOffset], read_md, reserved_data) == read_md) {
		                __threadfence();
		                
		                DWORD write_md;
		                
		                uint64_t tag = getBits(dataOffset / mdArrayLen, 0, SZ_TAG);
		                // Tag mismatch, reset metadata
		                if(getBits(read_md, BIT2_TAG, SZ_TAG) != tag) {
		                    write_md = 0;
		                    read_md = 0;
		                }
		                else
		                    write_md = atomicAdd(&((ULL**)metadata)[WR_MD][mdOffset], 0);
		                
		                race_read_md = read_md;
		                race_write_md = write_md;
		                detected_race = do_racecheck(write_md, read_md, mdOffset, (void**)counters, op_mask, scope, extra, parameters, mask);
		                setup_metadata(write_md, read_md, (void**)counters, op_mask, scope, parameters);
		                setBits(read_md, BIT2_TAG, SZ_TAG, tag); // set tag
		                atomicExch(&((ULL**)metadata)[WR_MD][mdOffset], write_md);
		                __threadfence();
		                atomicExch(&((ULL**)metadata)[RD_MD][mdOffset], read_md);
		                complete = true;
		            }
		            else {
		                if(delay) {
		                    csleep(delay);
		                    delay *= 2;
		                    delay = min(delay, MAX_DELAY);
		                }
		            }
		        } while(!complete);
		        
		        if(detected_race != NO_RACE) {
		            unsigned mask = __activemask();
		            unsigned selectedThread = ((mask - 1) & mask) ^ mask;
		            // Only last thread updates
		            if((1 << tid) & selectedThread) {
		                uint64_t WARPS_PER_BLK = roundUp(blockDim.x * blockDim.y * blockDim.z, WARP_SIZE);
		                // Local threadId, i.e. within a single block
		                uint64_t tid = serializeId(threadIdx.x, threadIdx.y, threadIdx.z, blockDim.x, blockDim.y, blockDim.z);
		                // Local warpId, i.e. within a single block
		                uint64_t wid = tid / WARP_SIZE;
		                // BlockId
		                uint64_t bid = serializeId(blockIdx.x, blockIdx.y, blockIdx.z, gridDim.x, gridDim.y, gridDim.z);
		                // Global warpId i.e. across all blocks
		                uint64_t g_wid = wid + bid * WARPS_PER_BLK;
		                uint64_t g_tid = (g_wid << 5) | (tid & ((ONE << 5) - ONE));
		                mem_access_t ma;
		                ma.addr = addr + internalOffset;
		                
		                ma.warp_id   = g_tid;
		                ma.opcode_id = opcode_id;
		                ma.read_md   = race_read_md;
		                ma.write_md  = race_write_md;
		                ma.reason    = detected_race;
		                ma.extra     = extra;
		                
		                ChannelDev *channel_dev = (ChannelDev *)pchannel_dev;
		                channel_dev->push(&ma, sizeof(mem_access_t));
		            }
		        }
		    }
			internalOffset += (uint64_t)((uint32_t*)parameters)[BYTE_GRAN];
		} while(internalOffset < dataSize);
    }
    __syncwarp(mask);
}
