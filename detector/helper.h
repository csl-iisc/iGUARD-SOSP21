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

#include "common.h"
#include "opcode.h"

uint32_t isStrong(Instr *inst)
{
    return (strstr(inst->getOpcode(), OP_STRONG) != NULL) || (inst->isLoad() && inst->isStore());
}

uint32_t isFence(Instr *inst)
{
    return strstr(inst->getOpcode(), OP_FENCE) != NULL;
}

uint32_t isBarrier(Instr *inst)
{
    return strstr(inst->getOpcode(), OP_BARRIER) != NULL;
}

uint32_t isWarpBar(Instr *inst)
{
    return strstr(inst->getSass(), OP_WAR_BAR) != NULL;
}

uint32_t isCAS(Instr *inst)
{
    return strstr(inst->getOpcode(), OP_CAS) != NULL;
}

uint32_t isExch(Instr *inst)
{
    return strstr(inst->getOpcode(), OP_EXCH) != NULL;
}

scope_t getScope(Instr *inst)
{
    if(strstr(inst->getOpcode(), OP_SYS_SCOPE) != NULL)
        return SCOPE_SYS;
    if(strstr(inst->getOpcode(), OP_GPU_SCOPE) != NULL)
        return SCOPE_GPU;
    if(strstr(inst->getOpcode(), OP_CTA_SCOPE) != NULL)
        return SCOPE_CTA;
    return SCOPE_NONE;
}
