﻿using System;
using System.Diagnostics.CodeAnalysis;
using Llvm.NET.DebugInfo;
using Llvm.NET.Native;

namespace Llvm.NET.Values
{
    /// <summary>An LLVM Global Variable</summary>
    public class GlobalVariable
        : GlobalObject
    {
        /// <summary>Flag to indicate if this variable is initialized in an external module</summary>
        public bool IsExternallyInitialized
        {
            get => NativeMethods.IsExternallyInitialized( ValueHandle );
            set => NativeMethods.SetExternallyInitialized( ValueHandle, value );
        }

        /// <summary>Gets or sets if this global is a Constant</summary>
        public bool IsConstant
        {
            get => NativeMethods.IsGlobalConstant( ValueHandle );
            set => NativeMethods.SetGlobalConstant( ValueHandle, value );
        }

        /// <summary>Flag to indicate if this global is stored per thread</summary>
        public bool IsThreadLocal
        {
            get => NativeMethods.IsThreadLocal( ValueHandle );
            set => NativeMethods.SetThreadLocal( ValueHandle, value );
        }

        /// <summary>Initial value for the variable</summary>
        public Constant Initializer
        {
            get
            {
                var handle = NativeMethods.GetInitializer( ValueHandle );
                if( handle.Pointer == IntPtr.Zero )
                {
                    return null;
                }

                return FromHandle<Constant>( handle );
            }

            set => NativeMethods.SetInitializer( ValueHandle, value?.ValueHandle ?? new LLVMValueRef( IntPtr.Zero ) );
        }

        [SuppressMessage( "Microsoft.Design", "CA1011:ConsiderPassingBaseTypesAsParameters", Justification = "Specific type required by interop" )]
        public void AddDebugInfo(DIGlobalVariableExpression expression)
        {
            expression.VerifyArgNotNull( nameof( expression ) );

            NativeMethods.GlobalVariableAddDebugExpression( ValueHandle, expression.MetadataHandle );
        }

        /// <summary>Removes the value from its parent module, but does not delete it</summary>
        public void RemoveFromParent() => NativeMethods.RemoveGlobalFromParent( ValueHandle );

        internal GlobalVariable( LLVMValueRef valueRef )
            : base( valueRef )
        {
        }
    }
}
