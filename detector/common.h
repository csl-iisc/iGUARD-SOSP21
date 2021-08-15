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
#include <string.h>
#ifndef COMMON_H
#define COMMON_H

#define WARP_SIZE 32
#define LKS_PER_THD 3
#define LOCK_SIZE 21

#define BYTE  uint8_t
#define HWORD uint16_t
#define WORD  uint32_t
#define DWORD uint64_t
#define ULL   unsigned long long int

// Needed to avoid typecasting issues
#define ONE ((uint64_t)1)

#ifdef DEBUG
#define debug_printf(...) { unsigned masker = __activemask(); \
        unsigned sThread = ((masker - 1) & masker) ^ masker; \
        if((1 << (threadIdx.x % WARP_SIZE)) & sThread) printf(__VA_ARGS__);}
#else
#define debug_printf(...) 
#endif

/* information collected in the instrumentation function and passed
 * on the channel from the GPU to the CPU */
typedef struct {
    uint64_t warp_id;
    int opcode_id;
    uint64_t addr;
    uint64_t read_md;
    uint64_t write_md;
    uint32_t reason;
    uint64_t extra;
} mem_access_t;

// Different types of scopes
typedef enum : uint32_t { 
    SCOPE_NONE = 0,
    SCOPE_CTA,
    SCOPE_GPU,
    SCOPE_SYS
} scope_t;

// Counter offsets
typedef enum : uint32_t {
    WARP_CTRS,
    BARRIER,
    WARP_BAR,
    LOCKS,
    TOTAL_CTRS
} counters_index;

// Byte for each counter
typedef enum : uint32_t {
    GPU_FENCE = 0,
    BLK_FENCE = 1,
    SZ_CTR = 8,
    CTR_MOVED = 14,
} warp_ctrs_index;

typedef enum : uint32_t {
    WR_MD = 0,
    RD_MD,
    TOTAL_MD,
} md_index;

typedef enum : uint32_t {
    BYTE_GRAN = 0,
    OPTIONS,
    TOTAL_PARAMS,
} param_index;

/************************************************************************************************************
 * METADATA FORMAT
 *
 * WRITE MD
 * Valid [63] + Modified [62] + Atom [61] + Scope [60] + BlkShared [59] + DevShared [58] + Unused [57 - 54]
 *
 * Read MD
 * Tag [63 - 54] 
 *
 * COMMON
 *  + TId [53 - 34] + GFence [33 - 28] + BFence [27 - 22] + 
 * Barrier [21 - 14] + WBar [13 - 8] + Lock bf [7 - 0]
 ***********************************************************************************************************/

typedef enum : uint64_t {
    BIT1_VALID  = 63,
    BIT_STRONG  = 63,
    BIT1_MOD    = 62,
    BIT1_ATOMIC = 61,
    BIT1_SCOPE  = 60,
    BIT1_BSHR   = 59,
    BIT1_GSHR   = 58,
    BIT2_TAG    = 54,
    BIT_TID     = 34,
    BIT_WID     = BIT_TID + 5, // WID and TID intersect
    BIT_GFENCE  = 28,
    BIT_BFENCE  = 22,
    BIT_BAR     = 14,
    BIT_WBAR    = 8,
    BIT_LOCKS   = 0,
} bit_positions_t;

typedef enum : uint64_t {
    SZ_TID    = 20,
    SZ_WID    = SZ_TID - 5, // WID and TID intersect
    SZ_GFENCE = 6,
    SZ_BFENCE = 6,
    SZ_BAR    = 8,
    SZ_WBAR   = 6,
    SZ_LOCKS  = 8,
    SZ_TAG    = 10,
} bit_sizes_t;

typedef enum : uint32_t {
    MASK_LOAD   = 1,
    MASK_STORE  = 2,
    MASK_ATOMIC = 3, // (MASK_LOAD | MASK_STORE)
    MASK_STRONG = 4,
    MASK_CAS    = 8,
    MASK_EXCH   = 16,
} op_mask_t;

typedef enum : uint32_t {
    MASK_CHECK_LOCKS = 1,
    MASK_LOCK_GRAN   = 2,
    MASK_CHECK_ITS   = 4,
} par_mask_t;

typedef enum : uint64_t {
    LKBIT_DATA   = 0,
    LKBIT_SCOPE  = LOCK_SIZE - 3,
    LKBIT_ACTIVE = LOCK_SIZE - 2,
    LKBIT_VALID  = LOCK_SIZE - 1,
    LKDATA_SIZE  = LKBIT_SCOPE - LKBIT_DATA,
    
    LKBIT_MOVED  = 63, // 1 bit per table
} lock_bits;

typedef enum : uint32_t {
    NO_RACE = 0,
    RACE_BFENCE,
    RACE_GFENCE,
    RACE_STRONG,
    RACE_ATOMIC,
    RACE_LOCK,
    RACE_ITS,
} race_types;

static __inline__ __device__ const char *scopeToStr(scope_t scope)
{
    switch(scope) {
        case SCOPE_CTA: return "CTA"; break;
        case SCOPE_GPU: return "GPU"; break;
        case SCOPE_SYS: return "SYS"; break;
        default:
        case SCOPE_NONE: return "NONE"; break;
    }
}

#define hasMask(val, mask) (((val) & (mask)) == (mask))
#define roundUp(divisor, dividend) CEILING(divisor, dividend)

static __inline__ __device__ int serializeId(int x, int y, int z, int xSize, int ySize, int zSize)
{
    return x + (y + z * ySize) * xSize; 
}

static __inline__ __device__ __host__ uint64_t getBit(uint64_t loc, uint64_t offset)
{
    return (((ONE << offset) & loc) ? ONE : 0);
}

static __inline__ __device__ __host__ void setBit(uint64_t &loc, uint64_t offset, uint64_t val = ONE)
{
    if(val) // Set bit
        loc = ((ONE << offset) | loc);
    else    // Unset bit
        loc = ((~(ONE << offset)) & loc);
}

static __inline__ __device__ __host__ uint64_t getBits(uint64_t loc, uint64_t start, uint64_t depth)
{
    return (loc >> start) & ((ONE << depth) - ONE);
}

static __inline__ __device__ __host__ void setBits(uint64_t &loc, uint64_t start, uint64_t depth, uint64_t val)
{
    // Unset bits from start to start + depth
    if(start + depth == 64) // Special case to avoid overflow
        loc &= ~((0xffffffffffffffff) ^ ((ONE << start) - ONE));
    else
        loc &= ~(((ONE << (start + depth)) - ONE) ^ ((ONE << start) - ONE));
    loc |= ((val & ((ONE << depth) - ONE)) << start);
}
#endif /*COMMON_H*/
