# Llvm.Libs Nuget Support
LLVM is a large collection of libraries for building compiler back-ends that
supprts a great deal of customization and extensibility. Using LLVM either
requires building the entire source tree or access to pre-built libraries.
The source is available, but building a full set of librraies for multiple
platforms and configurations (e.g. x86-Release, x64-Debug, etc...) can take
significant time in an automated build. Many Free for OSS project build services
like AppVeyor limit the total run time for any given build so building the
full source won't work there. Thus, this directorry includes support for building
the libraries on a local machine once and packed into a NuGet package. Projects
using LLVM can then reference the NuGet package to let nuget download the
libraries instead of having to build them.

Llvm.NET project maintains a nuget package for the official release of LLVM that
are built using this directory so you generally don't need to use this yourself.
However it is made available in case there is a need (like restrictions on external
nuget feeds etc...) so you can create your own copy of the packages but still build
projects that reference them.

## Usage
The simplest usage is to use the public Neget feed and add the "Llvm.Libs" package
to your project. The package includes all the headers and libraries from LLVM.

## Building the package localy
The [Build-Llvm.ps1](Build-Llvm.md) script is used to build the LLVM libraries and
bundle them into the nugetPackage.

### Building the nuget packages only
When working on a new version of LLVM it may be necessary to iterate on the props/targets
provided inthe nuget pacakges without rebuilding the LLVM libraries too. This is easily
accomplished with the following PowerShell command.

```PowerShell
.\Build-Llvm.ps1 -LlvmVersion 4.0.1 -BuildOutputPath D:\CMakeBuild\LLVM\4.0.1 -LlvmRoot D:\LLVM\4.0.1 -Generate:$false -Build:$false -CreateSettingsJson:$false -Pack -PackStyle MultiPack
```

