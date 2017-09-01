﻿using System;
using Llvm.NET.Native;

namespace Llvm.NET.Values
{
    public class GlobalObject
        : GlobalValue
    {
        internal GlobalObject( LLVMValueRef valueRef )
            : base( valueRef )
        {
        }

        /// <summary>Alignment requirements for this object</summary>
        public uint Alignment
        {
            get => NativeMethods.GetAlignment( ValueHandle );
            set => NativeMethods.SetAlignment( ValueHandle, value );
        }

        /// <summary>Linker section this object belongs to</summary>
        public string Section
        {
            get => NativeMethods.GetSection( ValueHandle );
            set => NativeMethods.SetSection( ValueHandle, value );
        }

        /// <summary>Gets or sets the comdat attached to this object, if any</summary>
        /// <remarks>
        /// Setting this property to <see langword="null"/> or an
        /// empty string will remove any comdat setting for the
        /// global object.
        /// </remarks>
        public Comdat Comdat
        {
            get
            {
                LLVMComdatRef comdatRef = NativeMethods.GlobalObjectGetComdat( ValueHandle );
                if( comdatRef.Pointer.IsNull( ) )
                {
                    return null;
                }

                return new Comdat( ParentModule, comdatRef );
            }

            set
            {
                if( value != null && value.Module != ParentModule )
                {
                    throw new ArgumentException( "Mismatched modules for Comdat", nameof( value ) );
                }

                NativeMethods.GlobalObjectSetComdat( ValueHandle, value?.ComdatHandle?? new LLVMComdatRef( IntPtr.Zero ) );
            }
        }
    }
}
