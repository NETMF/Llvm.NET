# Llvm.Libs Nuget Support
Detached branch of Llvm.NET for building and publishing the LLVM libraries and
header files.

## About
LLVM is a large collection of libraries for building compiler back-ends that
supports a great deal of customization and extensibility. Using LLVM either
requires building the entire source tree or access to pre-built libraries.
The source is available, but building a full set of libraries for multiple
platforms and configurations (e.g. x86-Release, x64-Debug, etc...) can take
significant time in an automated build. Many Free for OSS project build services
like [AppVeyor](http://AppVeyor.com) limit the total run time for any given build
so building the full source won't work there. Thus, this directory includes support
for building the libraries on a local machine once and packed into a NuGet package.
Projects using LLVM can then reference the NuGet package to let NuGet download the
libraries instead of having to build them.

Llvm.NET project maintains a NuGet package for the official releases of LLVM that
are built using this directory. **Thus, you generally don't need to use this yourself.**
However it is made available in case there is a need (like restrictions on external
NuGet feeds etc...) so you can create your own copy of the packages but still build
projects that reference them.

## Usage
The simplest usage is to use the public NuGet feed and add the "Llvm.Libs" package
to your project. The package includes all the headers and libraries from LLVM.

## Building the package localy
The [Build-Llvm.ps1](Build-Llvm.md) script is used to build the LLVM libraries and
bundle them into the nugetPackage.

### Building the nuget packages only
When working on a new version of LLVM it may be necessary to iterate on the props/targets
provided in the NuGet packages without rebuilding the LLVM libraries too. This is easily
accomplished with the following PowerShell command.

```PowerShell
.\Build-Llvm.ps1 -Pack -LlvmVersion 4.0.1 -BuildOutputPath D:\CMakeBuild\LLVM\4.0.1 -LlvmRoot D:\LLVM\4.0.1 
```
 (Of course you should substitute the paths in the example command to match your own system.)

