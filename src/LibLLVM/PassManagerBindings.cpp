//===- InstrumentationBindings.cpp - instrumentation bindings -------------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This file defines C bindings for the instrumentation component.
//
//===----------------------------------------------------------------------===//

#include "PassManagerBindings.h"

#include "llvm-c/Core.h"
#include "llvm/IR/LegacyPassManager.h"
#include "llvm/IR/Module.h"
#include "llvm/Transforms/Instrumentation.h"
#include "llvm/PassRegistry.h"

using namespace llvm;

extern "C"
{
    LLVMPassRegistryRef LLVMCreatePassRegistry( )
    {
        return wrap( new PassRegistry( ) );
    }

    void LLVMPassRegistryDispose( LLVMPassRegistryRef passReg )
    {
        delete unwrap( passReg );
    }

    void LLVMAddAddressSanitizerFunctionPass( LLVMPassManagerRef PM )
    {
        unwrap( PM )->add( createAddressSanitizerFunctionPass( ) );
    }

    void LLVMAddAddressSanitizerModulePass( LLVMPassManagerRef PM )
    {
        unwrap( PM )->add( createAddressSanitizerModulePass( ) );
    }

    void LLVMAddThreadSanitizerPass( LLVMPassManagerRef PM )
    {
        unwrap( PM )->add( createThreadSanitizerPass( ) );
    }

    void LLVMAddMemorySanitizerPass( LLVMPassManagerRef PM )
    {
        unwrap( PM )->add( createMemorySanitizerPass( ) );
    }

    void LLVMAddDataFlowSanitizerPass( LLVMPassManagerRef PM, int ABIListFilesNum, const char **ABIListFiles )
    {
        std::vector<std::string> ABIListFilesVec;
        for( int i = 0; i != ABIListFilesNum; ++i )
        {
            ABIListFilesVec.push_back( ABIListFiles[ i ] );
        }

        unwrap( PM )->add( createDataFlowSanitizerPass( ABIListFilesVec ) );
    }

    // For codegen passes, only passes that do IR to IR transformation are
    // supported.
    void LLVMInitializeCodeGenForOpt( LLVMPassRegistryRef R )
    {
        PassRegistry& Registry = *unwrap( R );
        initializeCore( Registry );
        initializeCoroutines( Registry );
        initializeScalarOpts( Registry );
        initializeObjCARCOpts( Registry );
        initializeVectorization( Registry );
        initializeIPO( Registry );
        initializeAnalysis( Registry );
        initializeTransformUtils( Registry );
        initializeScalarizeMaskedMemIntrinPass( Registry );
        initializeInstCombine( Registry );
        initializeInstrumentation( Registry );
        initializeTarget( Registry );
        // For codegen passes, only passes that do IR to IR transformation are
        // supported.
        initializeCodeGenPreparePass( Registry );
        initializeAtomicExpandPass( Registry );
        initializeRewriteSymbolsLegacyPassPass( Registry );
        initializeWinEHPreparePass( Registry );
        initializeDwarfEHPreparePass( Registry );
        initializeSafeStackLegacyPassPass( Registry );
        initializeSjLjEHPreparePass( Registry );
        initializePreISelIntrinsicLoweringLegacyPassPass( Registry );
        initializeGlobalMergePass( Registry );
        initializeInterleavedAccessPass( Registry );
        initializeCountingFunctionInserterPass( Registry );
        initializeUnreachableBlockElimLegacyPassPass( Registry );
        initializeExpandReductionsPass( Registry );
    }
}