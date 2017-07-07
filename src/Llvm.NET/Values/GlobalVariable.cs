using System;
using System.Collections.Generic;
using Llvm.NET.DebugInfo;
using Llvm.NET.Native;

namespace Llvm.NET.Values
{
    /*internal class GveDebugInfoCollection
    //    : ICollection<DIGlobalVariableExpression>
    //{
    //    internal GveDebugInfoCollection(GlobalVariable var)
    //    {
    //        ContainingGlobal = var;
    //    }

    //    public int Count => throw new NotImplementedException( );

    //    public bool IsReadOnly => false;

    //    public void Add( DIGlobalVariableExpression item )
    //        => NativeMethods.GlobalVariableAddDebugExpression( item?.MetadataHandle ?? throw new ArgumentNullException(nameof(item)) );

    //    public void Clear( )
    //    {
    //        throw new NotImplementedException( );
    //    }

    //    public bool Contains( DIGlobalVariableExpression item )
    //    {
    //        throw new NotImplementedException( );
    //    }

    //    public void CopyTo( DIGlobalVariableExpression[ ] array, int arrayIndex )
    //    {
    //        throw new NotImplementedException( );
    //    }

    //    public IEnumerator<DIGlobalVariableExpression> GetEnumerator( )
    //    {
    //        throw new NotImplementedException( );
    //    }

    //    public bool Remove( DIGlobalVariableExpression item )
    //    {
    //        throw new NotImplementedException( );
    //    }

    //    IEnumerator IEnumerable.GetEnumerator( )
    //    {
    //        throw new NotImplementedException( );
    //    }

    //    // temp suppress warning until this is completed
    //    [SuppressMessage( "Microsoft.Performance", "CA1823:AvoidUnusedPrivateFields", Justification = "Temporary state" )]
    //    private GlobalVariable ContainingGlobal;
    //}
    */

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

        [System.Diagnostics.CodeAnalysis.SuppressMessage( "Microsoft.Performance", "CA1822:MarkMembersAsStatic", Justification = "Temp until details of globalvariable support finished" )]
        public ICollection<DIGlobalVariableExpression> DebugInfo => null; // => DebugInfoCollection;
        // GveDebugInfoCollection DebugInfoCollection;

        /// <summary>Removes the value from its parent module, but does not delete it</summary>
        public void RemoveFromParent() => NativeMethods.RemoveGlobalFromParent( ValueHandle );

        internal GlobalVariable( LLVMValueRef valueRef )
            : base( valueRef )
        {
            // DebugInfoCollection = new GveDebugInfoCollection( this );
        }
    }
}
