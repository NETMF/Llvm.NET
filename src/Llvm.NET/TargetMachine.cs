﻿using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using Llvm.NET.Native;

namespace Llvm.NET
{
    /// <summary>Target specific code generation information</summary>
    public class TargetMachine : IDisposable
    {
        /// <summary>Retrieves the Target that owns this <see cref="TargetMachine"/></summary>
        public Target Target => Target.FromHandle( NativeMethods.GetTargetMachineTarget( TargetMachineHandle ) );

        /// <summary>Target triple describing this machine</summary>
        public string Triple => NativeMethods.MarshalMsg( NativeMethods.GetTargetMachineTriple( TargetMachineHandle ) );

        /// <summary>CPU Type for this machine</summary>
        public string Cpu => NativeMethods.MarshalMsg( NativeMethods.GetTargetMachineCPU( TargetMachineHandle ) );

        /// <summary>CPU specific features for this machine</summary>
        public string Features => NativeMethods.MarshalMsg( NativeMethods.GetTargetMachineFeatureString( TargetMachineHandle ) );

        /// <summary>Gets Layout information for this machine</summary>
        public DataLayout TargetData
        {
            get
            {
                var handle = NativeMethods.CreateTargetDataLayout( TargetMachineHandle );
                if( handle.Pointer == IntPtr.Zero )
                    return null;

                return DataLayout.FromHandle( Context, handle, isDisposable: false );
            }
        }

        /// <summary>Generate code for the target machine from a module</summary>
        /// <param name="module"><see cref="NativeModule"/> to generate the code from</param>
        /// <param name="path">Path to the output file</param>
        /// <param name="fileType">Type of file to emit</param>
        public void EmitToFile( NativeModule module, string path, CodeGenFileType fileType )
        {
            if( module == null )
                throw new ArgumentNullException( nameof( module ) );

            if( string.IsNullOrWhiteSpace( path ) )
                throw new ArgumentException( "Null or empty paths are not valid", nameof( path ) );

            if( module.TargetTriple != null && Triple != module.TargetTriple )
                throw new ArgumentException( "Triple specified for the module doesn't match target machine", nameof( module ) );

            IntPtr errMsg;
            if( 0 != NativeMethods.TargetMachineEmitToFile( TargetMachineHandle, module.ModuleHandle, path, (LLVMCodeGenFileType)fileType, out errMsg ).Value )
            {
                var errTxt = NativeMethods.MarshalMsg( errMsg );
                throw new InternalCodeGeneratorException( errTxt );
            }
        }

        /// <summary>Generate code for the target machine from a module</summary>
        /// <param name="module"><see cref="NativeModule"/> to generate the code from</param>
        /// <param name="fileType">Type of file to emit</param>
        /// <returns>The emitted result in form of a <see cref="byte"/> array</returns>
        public byte[] EmitToBuffer( NativeModule module, CodeGenFileType fileType )
        {
            if( module == null )
                throw new ArgumentNullException( nameof( module ) );

            IntPtr errMsg;
            LLVMMemoryBufferRef bufferRef;
            if( 0 != NativeMethods.TargetMachineEmitToMemoryBuffer( TargetMachineHandle, module.ModuleHandle, (LLVMCodeGenFileType)fileType, out errMsg, out bufferRef ).Value )
            {
                var errTxt = NativeMethods.MarshalMsg( errMsg );
                throw new InternalCodeGeneratorException( errTxt );
            }

            Debug.Assert( bufferRef.Pointer != IntPtr.Zero, "Invalid buffer result" );

            try
            {
                var bufferStart = NativeMethods.GetBufferStart( bufferRef );
                var bufferSize = NativeMethods.GetBufferSize( bufferRef );

                var result = new byte[ bufferSize ];
                Marshal.Copy( bufferStart, result, 0, bufferSize );

                return result;
            }
            finally
            {
                NativeMethods.DisposeMemoryBuffer( bufferRef );
            }
        }

        /// <summary><see cref="Context"/>This machine is associated with</summary>
        public Context Context { get; }

        internal TargetMachine( Context context, LLVMTargetMachineRef targetMachineHandle )
        {
            TargetMachineHandle = targetMachineHandle;
            Context = context;
        }
       
        #region IDisposable Support
        private bool IsDisposed => TargetMachineHandle.Pointer == IntPtr.Zero;

        protected virtual void Dispose( bool disposing )
        {
            if( !IsDisposed )
            {
                // no managed state to dispose here
                //if( disposing )
                //{
                //    // dispose managed state (managed objects).
                //}
                NativeMethods.DisposeTargetMachine( TargetMachineHandle );
                TargetMachineHandle = default( LLVMTargetMachineRef );
            }
        }

        ~TargetMachine( )
        {
            // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
            Dispose( false );
        }

        // This code added to correctly implement the disposable pattern.
        public void Dispose( )
        {
            // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
            Dispose( true );
            GC.SuppressFinalize(this);
        }
        #endregion

        internal LLVMTargetMachineRef TargetMachineHandle { get; private set; }
    }
}
