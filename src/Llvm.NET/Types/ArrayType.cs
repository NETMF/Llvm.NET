﻿using System;
using Llvm.NET.Native;

namespace Llvm.NET.Types
{
    /// <summary>Interface for an LLVM array type </summary>
    public interface IArrayType
        : ISequenceType
    {
        /// <summary>Length of the array</summary>
        uint Length { get; }
    }

    /// <summary>Array type definition</summary>
    /// <remarks>
    /// Array's in LLVM are fixed length sequences of elements
    /// </remarks>
    internal class ArrayType
        : SequenceType
        , IArrayType
    {
        /// <summary>Length of the array</summary>
        public uint Length => NativeMethods.GetArrayLength( TypeHandle_ );

        internal ArrayType( LLVMTypeRef typeRef )
            : base( typeRef )
        {
            if( NativeMethods.GetTypeKind( typeRef ) != LLVMTypeKind.LLVMArrayTypeKind )
            {
                throw new ArgumentException( "Array type reference expected", nameof( typeRef ) );
            }
        }
    }
}
