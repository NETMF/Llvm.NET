#Requires -Version 5.0

# ensure the output locations exist
Set-StrictMode -Version Latest

function New-LlvmCmakeConfig([string]$platform,
                             [string]$config,
                             [string]$baseBuild = (Join-Path (Get-Location) BuildOutput),
                             [string]$srcRoot = (Join-Path (Get-Location) llvm)
                            )
{
    #TODO: Need to set LLVM_TARGET_ARCH for JIT support as it will default to that of "host" at build time
    # which means JIT can only target one platform... (also should check for LLVM_ENABLE_JIT_EVENTS)
    # Longer term need to determine better way of handling these options with pure interface based implementation
    # and MEF/Linq searching to find matching implementation for desired use at run time. This could keep the
    # actual DLLs smaller at the expense of making the initialization a bit more complex (Though, it could
    # use a disposable to expose the outer most layer APIs that would handle the static init and shutdown along
    # with command line option parsing for LLVM args... )
    [CMakeConfig]$cmakeConfig = New-Object CMakeConfig -ArgumentList $platform, $config, $baseBuild, $srcRoot
    $cmakeConfig.CMakeBuildVariables = @{
        LLVM_ENABLE_RTTI = "ON"
        LLVM_ENABLE_CXX1Y = "ON"
        LLVM_BUILD_TOOLS = "OFF"
        LLVM_BUILD_DOCS = "OFF"
        LLVM_BUILD_RUNTIME = "OFF"
        LLVM_OPTIMIZED_TABLEGEN = "ON"
        LLVM_REVERSE_ITERATION = "ON"
        LLVM_TARGETS_TO_BUILD  = "all"
        CMAKE_MAKE_PROGRAM=Join-Path $RepoInfo.VSInstance.InstallationPath 'COMMON7\IDE\COMMONEXTENSIONS\MICROSOFT\CMAKE\Ninja\ninja.exe'
    }
    return $cmakeConfig
}
Export-ModuleMember -Function New-LlvmCmakeConfig

function Get-LlvmVersion( [string] $cmakeListPath )
{
    $props = @{}
    $matches = Select-String -Path $cmakeListPath -Pattern "set\(LLVM_VERSION_(MAJOR|MINOR|PATCH) ([0-9])+\)" |
        %{ $_.Matches } |
        %{ $props.Add( $_.Groups[1].Value, [Convert]::ToInt32($_.Groups[2].Value) ) }
    "$($props.Major).$($props.Minor).$($props.Patch)"
}
Export-ModuleMember -Function Get-LlvmVersion

function BuildPlatformConfigPackage([CmakeConfig]$config, $version, $packOutputPath, $nuspecOutputPath)
{
    Write-Information "Generating Llvm.Libs.$($config.Name).nupkg"
    $properties = MakePropList @{ llvmsrcroot=$srcRoot
                                  llvmbuildroot=$config.BuildRoot
                                  version=$version
                                  platform=$config.Platform
                                  configuration=$config.ConfigurationType
                                  nugetsrcdir=(ConvertTo-NormalizedPath (Get-Location))
                                }

    Invoke-Nuget pack Llvm.Libs.core.Platform-Configuration.nuspec -properties $properties -OutputDirectory $packOutputPath
    if( $config -ieq "Debug")
    {
        Invoke-Nuget pack Llvm.Libs.core.pdbs.Platform-Configuration.nuspec -properties $properties -OutputDirectory $packOutputPath
    }

    # generate nuspec for each target arch, platform, config from the template
    $nuspec = [xml](Get-Content Llvm.Libs.targets.nuspec.template)
    $nuspecNamespace = 'http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd'
    $ns = @{nuspec=$nuspecNamespace}
    $architectures = ("AArch64","AMDGPU","ARM","BPF","Hexagon","Lanai","Mips","MSP430","NVPTX","PowerPC","RISCV","Sparc","SystemZ","X86","XCore")
    $files = $nuspec | Select-Xml "//nuspec:files" -Namespace $ns
    foreach( $arch in $architectures)
    {
        foreach( $item in (Get-ChildItem -Path (join-path $config.BuildRoot "$($config.Name)\$($config.ConfigurationType)\lib") -Filter "Llvm$arch*"))
        {
            $fileElement = $nuspec.CreateElement("file",$nuspecNamespace);
            $srcAttrib = $nuspec.CreateAttribute("src")
            $srcAttrib.InnerText = "`$llvmbuildroot`$`$platform`$-`$configuration`$\`$configuration`$\lib\$($item.Name)"
            $targetAttrib = $nuspec.CreateAttribute("target")
            $targetAttrib.InnerText = 'lib\native\lib'
            $fileElement.Attributes.Append( $srcAttrib )  | Out-Null
            $fileElement.Attributes.Append( $targetAttrib )  | Out-Null
            $files.Node.AppendChild( $fileElement )  | Out-Null
        }
    }

    # generate nuget package from the generated nuspec file
    $generatedNuSpec = join-path $nuspecOutputPath "Llvm.Libs.targets.$($config.Name).nuspec"
    $nuspec.Save($generatedNuSpec) | Out-Null
    Invoke-Nuget pack $generatedNuSpec -properties $properties -OutputDirectory $packOutputPath
}

function GenerateMultiPack($version, $srcRoot, $buildOutput, $packOutputPath)
{
    Write-Information "Generating meta-package"
    $properties = MakePropList @{ llvmsrcroot=$srcRoot
                                  llvmbuildroot=$buildOutput;
                                  version=$version
                                }

    Invoke-Nuget pack .\Llvm.Libs.MetaPackage.nuspec -Properties $properties -OutputDirectory $packOutputPath
}

function Get-AllCmakeConfigs
{
    # Construct array of configurations to deal with
    return @( (New-LlvmCmakeConfig x86 "Debug" $RepoInfo.BuildOutputPath $RepoInfo.LlvmRoot),
              (New-LlvmCmakeConfig x86 "Release" $RepoInfo.BuildOutputPath $RepoInfo.LlvmRoot),
              (New-LlvmCmakeConfig x64 "Debug" $RepoInfo.BuildOutputPath $RepoInfo.LlvmRoot),
              (New-LlvmCmakeConfig x64 "Release" $RepoInfo.BuildOutputPath $RepoInfo.LlvmRoot)
            )
}
Export-ModuleMember -Function Get-AllCmakeConfigs

function LlvmBuildConfig([CMakeConfig]$configuration)
{
    Invoke-CMakeGenerate $configuration
    Invoke-CmakeBuild $configuration
    BuildPlatformConfigPackage $configuration $version $PackOutputPath $NuspecOutputPath
}

function Invoke-CMakeGenerator
{
    param(
           [Parameter(Mandatory=$true)]
           [ValidateSet('x86','x64')]
           [string]
           $Platform,

           [Parameter(Mandatory=$true)]
           [ValidateSet('Release','Debug')]
           [string]
           $Configuration
    )

    $cmakeConfig = New-LlvmCmakeConfig $Platform $Configuration $RepoInfo.BuildOutputPath $RepoInfo.LlvmRoot
    Invoke-CMakeGenerate $cmakeConfig
}
Export-ModuleMember -Function Invoke-CMakeGenerator

function New-CMakeSettingsJson
{
    Get-AllCmakeConfigs | New-CmakeSettings | Format-Json
}
Export-ModuleMember -Function New-CMakeSettingsJson

function Invoke-Build
{
<#
.SYNOPSIS
    Wraps CMake Visual Studio solution generation and build for LLVM as used by the LLVM.NET project

.DESCRIPTION
    This script is used to build LLVM libraries for Windows and bundle the results into a NuGet package.
    A NUGET package is immediately consumable by projects without requiring a complete build of the LLVM
    source code. This is particularly useful for OSS projects that leverage public build services like
    Jenkins or AppVeyor, etc... Public build services often limit the time a build can run so building
    all of the LLVM libraries for multiple platforms can be problematic as the LLVM builds take quite
    a while on their own. Furthermore public services often limit the size of each NuGet package to some
    level (Nuget.org tops out at 250MB). So the NuGet Packaging supports splitting out the libraries,
    headers and symbols into smaller packages with a top level "MetaPackage" that lists all the others
    as dependencies. The complete set of packages is:
       - Llvm.Libs.<Version>.nupkg
       - Llvm.Libs.core.pdbs.x64-Debug.<Version>.nupkg
       - Llvm.Libs.core.pdbs.x86-Debug.<Version>.nupkg
       - Llvm.Libs.core.x64-Debug.<Version>.nupkg
       - Llvm.Libs.core.x64-Release.<Version>.nupkg
       - Llvm.Libs.core.x86-Debug.<Version>.nupkg
       - Llvm.Libs.core.x86-Release.<Version>.nupkg
       - Llvm.Libs.targets.x64-Debug.<Version>.nupkg
       - Llvm.Libs.targets.x64-Release.<Version>.nupkg
       - Llvm.Libs.targets.x86-Debug.<Version>.nupkg
       - Llvm.Libs.targets.x86-Release.<Version>.nupkg

.PARAMETER BuildOutputPath
    The path to where the projects are generated and the binaries they build will be located.

.PARAMETER Generate
    Switch to run CMAKE configuration and project/solution generation

.PARAMETER BuildAll
    Switch to enable building all the platform configurations in a single run.
    > **NOTE:**
    The full build can take as much as 1.5 to 2 hours on common current hardware using most of the CPU and disk I/O capacity,
    therefore you should plan accordingly and only use this command when the system would otherwise be idle.

.PARAMETER Build
    Switch to build and pack one platform and configuration package. This will build the LLVM libraries for the particular
    platform/configuration combination and then pack them into a NuGet package.

.PARAMETER Platform
    Defines the platform to target. The AnyCPU platform has special meaning and is used to pack the platform/configuration neutral
    Meta-Package NuGet Package. That is, the Configuration parameter is ignored if Platform is AnyCPU.

.PARAMETER Configuration
    Defines the configuration to build

.PARAMETER LlvmRoot
    This specifies the root of the LLVM source tree to build.

.PARAMETER Pack
    Set this flag to generate the NuGet packages for the libraries and headers

.PARAMETER PackOutputPath
    Defines the output location for package generation. The default location is .\packages.

.PARAMETER NuspecOutputPath
   Defines the path for generated Nuspec files when packing
#>

    [CmdletBinding(DefaultParameterSetName="buildall")]
    param(
       [Parameter(ParameterSetName="build")]
       [Parameter(ParameterSetName="buildall")]
       [Parameter(ParameterSetName="pack")]
       [string]
       $BuildPaths = $RepoInfo,

       [Parameter(ParameterSetName="Generate")]
       [switch]
       $Generate=$true,

       [Parameter(ParameterSetName="buildall")]
       [switch]
       $BuildAll,

       [Parameter(ParameterSetName="build")]
       [switch]
       $Build,

       [Parameter(ParameterSetName="build")]
       [ValidateSet('x86','x64','AnyCPU')]
       [string]
       $Platform,

       [Parameter(ParameterSetName="build")]
       [ValidateSet('Release','Debug')]
       [string]
       $Configuration,

       [Parameter(ParameterSetName="pack")]
       [switch]$Pack
     )

    $version = (Get-LlvmVersion (Join-Path $RepoInfo.LlvmRoot 'CMakeLists.txt'))

    switch( $PsCmdlet.ParameterSetName )
    {
        "build" {
            if( $Platform -eq "AnyCPU" )
            {
                GenerateMultiPack $version $RepoInfo.LlvmRoot $RepoInfo.BuildOutputPath $PackOutputPath $NuspecOutputPath
            }
            else
            {
                $cmakeConfig = New-LlvmCmakeConfig $Platform $Configuration $RepoInfo.BuildOutputPath $RepoInfo.LlvmRoot
                LlvmBuildConfig $cmakeConfig
            }
        }
        "buildall" {
            try
            {
                $timer = [System.Diagnostics.Stopwatch]::StartNew()
                foreach( $cmakeConfig in (Get-AllCmakeConfigs) )
                {
                    LlvmBuildConfig $cmakeConfig
                }
                GenerateMultiPack $version $RepoInfo.LlvmRoot $RepoInfo.BuildOutputPath $RepoInfo.PackOutputPath $RepoInfo.NuspecOutputPath
            }
            finally
            {
                $timer.Stop()
                Write-Information "Finished: $activity - Time: $($timer.Elapsed.ToString())"
            }

        }
        "pack" {
            foreach( $cmakeConfig in (Get-AllCmakeConfigs) )
            {
                BuildPlatformConfigPackage $cmakeConfig $version $PackOutputPath $NuspecOutputPath
            }
            GenerateMultiPack $version $RepoInfo.LlvmRoot $RepoInfo.BuildOutputPath $RepoInfo.PackOutputPath $RepoInfo.NuspecOutputPath
        }
        default {
            Write-Error "Unknown parameter set '$PsCmdlet.ParameterSetName'"
        }
    }

    if( $Error.Count > 0 )
    {
        $Error.GetEnumerator() | %{ $_ }
    }
}
Export-ModuleMember -Function Invoke-Build

function EnsureBuildPath([string]$path)
{
    $resultPath = $([System.IO.Path]::Combine($PSScriptRoot, '..', '..', $path))
    if( !(Test-Path -PathType Container $resultPath) )
    {
        md $resultPath
    }
    else
    {
        Get-Item $resultPath
    }
}

function Get-RepoInfo
{
    return @{
        NuspecPath = EnsureBuildPath 'nuspec'
        ToolsPath =  EnsureBuildPath 'tools'
        BuildOutputPath = EnsureBuildPath 'BuildOutput'
        PackOutputPath = EnsureBuildPath 'packages'
        LlvmRoot = (Get-Item $([System.IO.Path]::Combine($PSScriptRoot, '..', '..', 'llvm')))
        VsInstance = Find-VSInstance
    }
}

function Initialize-BuildEnvironment
{
    $env:__LLVM_BUILD_INITIALIZED=1
    $env:Path = "$($RepoInfo.ToolsPath);$env:Path"
    <#
    NUMBER_OF_PROCESSORS < 6;
    This is generally an inefficient number of cores available (Ideally 6-8 are needed for a timely build)
    On an automated build service this may cause the build to exceed the time limit allocated for a build
    job. (As an example AppVeyor has a 1hr per job limit with VMs containing only 2 cores, which is
    unfortunately just not capable of completing the build in time.)
    #>

    if( ([int]$env:NUMBER_OF_PROCESSORS) -lt 6 )
    {
        Write-Warning "NUMBER_OF_PROCESSORS{ $env:NUMBER_OF_PROCESSORS } < 6;"
    }

    if(!$RepoInfo.VsInstance)
    {
        Write-Error "No VisualStudio or Build tools instances found"
    }
    else
    {
        $env:Path="$(Join-Path $RepoInfo.VsInstance.InstallationPath 'COMMON7\IDE\COMMONEXTENSIONS\MICROSOFT\CMAKE\CMake\bin');$env:Path"
        $env:Path="$(Join-Path $RepoInfo.VsInstance.InstallationPath 'COMMON7\IDE\COMMONEXTENSIONS\MICROSOFT\CMAKE\Ninja');$env:Path"
        Write-Host "Initializing VCVARS"
        Initialize-VCVars $RepoInfo.VsInstance
    }
}
Export-ModuleMember -Function Initialize-BuildEnvironment

function Install-PreRequisites
{
    #all prerequisites could be obtained from VS community install
    # https://www.visualstudio.com/downloads/
    # unfortunately it isn't a direct download link to allow automated downloads
    # need minimum:
    #    Microsoft.Component.MSBuild
    #    Microsoft.VisualStudio.Component.CoreBuildTools
    #    Microsoft.VisualStudio.Component.VC.CoreBuildTools
    #    Microsoft.VisualStudio.Component.VC.CMake.Project
    #    Microsoft.VisualStudio.Component.VC.Tools.x86.x64
    #    Component.CPython2.x64 or Component.CPython2.x86
    #


    $NuGetExePath = Find-OnPath NuGet.exe -ErrorAction Continue
    if( !$NuGetExePath )
    {
        # Download it from official NuGet release location
        $nugetToolsPath = (Join-Path $RepoInfo.ToolsPath 'NuGet.exe')
        Write-Verbose "Downloading $nugetToolsPath"
        Invoke-WebRequest -UseBasicParsing -Uri https://dist.NuGet.org/win-x86-commandline/latest/NuGet.exe -OutFile $nugetToolsPath
    }

    # Find/Install Python
    $python = Find-Python
    if(!$python)
    {
        $pythonPath = Install-Python
        $env:Path="$env:Path;$pythonPath"
    }

    if( !$python.FoundOnPath )
    {
        $env:Path="$env:Path;$($python.BinPath)"
    }

    # Find/Install CMake - https://cmake.org/files/v3.9/cmake-3.9.2-win64-x64.msi OR https://cmake.org/files/v3.9/cmake-3.9.2-win32-x86.msi
    $cmake = Find-OnPath 'cmake.exe'
    if(!$cmake)
    {
        # TODO: try registry?
        Install-CMakeTools
    }

    # TODO: (maybe) if VSinstance not found with C++ and CMake support - download and install those...
    # (anyone using these libs should already have those. Furthermore, it can be a big install so best
    # left to user to install them.)

    $msBuildInfo = Find-MsBuild
    if( !$msBuildInfo )
    {
        throw "MSBuild was not found"
    }

    if( !$msBuildInfo.FoundOnPath )
    {
        $env:Path="$($msBuildInfo.BinPath);$env:Path"
    }
}
Export-ModuleMember -Function Install-PreRequisites

# --- Module init script
$RepoInfo = Get-RepoInfo
Export-ModuleMember -Variable $RepoInfo

"Build Paths:"
$RepoInfo
