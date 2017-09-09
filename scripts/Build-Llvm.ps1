#Requires -Version 5.0

<#
.SYNOPSIS
    Wraps CMake Visual Studio solution generation and build for LLVM as used by the LLVM.NET project

.DESCRIPTION
    This script is used to build LLVM libraries for Windows and bundle the results into a NuGet package.
    A NUGET package is immediately consumable by projects without requiring a complete build of the LLVM
    source code. This is particularly useful for OSS projects that leverage public build services like
    Jenkins or AppVeyor, etc... Public build services often limit the time a build can run so building
    all of the LLVM libraries for multiple platforms can be problematic as the LLVM builds take quite
    a while on their own. Furthermore public services often limit the size of each NuGet pacakge to some
    level (Nuget.org tops out at 250MB). So the Nuget Packaging supports splitting out the libraries,
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

.PARAMETER LlvmRoot
    This specifies the root of the LLVM source tree to build.

.PARAMETER BuildOutputPath
    The path to where the projects are generated and the binaries they build will be located.

.PARAMETER Generate
    Switch to run CMAKE configuration and project/solution generation

.PARAMETER BuildAll
    Switch to enable building all the platform configurations in a single run.
    > **NOTE:**  
    The full build can take as much as 1.5 to 2 hours on common current hardware using most of the CPU and disk I/O capacity,
    therfore you should plan accordingly and only use this command when the system would otherwise be idle.

.PARAMETER Build
    Switch to build and pack one platform and configuration package. This will build the LLVM libraries for the particular
    platform/configuration combination and then pack them into a NuGet pacage.

.PARAMETER Platform
    Defines the platform to target. The AnyCPU platform has special meaning and is used to pack the platform/configuration neutral
    Meta-Package NuGet Package. That is, the Configuration parameter is ignored if Platform is AnyCPU.

.PARAMETER Configuration
    Defines the configuration to build

.PARAMETER BaseVsGenerator
    This specifies the base name of the CMAKE Visual Studio Generator. This script will add the "Win64" part of the name when generating 64bit projects.

.PARAMETER CreateSettingsJson
    This flag generates the Visual Studio CMakeSettings.json file with the CMAKE settings for LLVM. This allows opening the source folder in
    Visual C++ tools for CMake in Visual Studio 2017 to build additional tools or brose the source etc...

.PARAMETER Pack
    Set this flag to generate the Nuget packages for the libraries and headers

.PARAMETER PackOutputPath
    Defines the output location for package generation. The default location is .\packages.

.PARAMETER NuspecOutputPath
   Defines the path for generated Nuspec files when packing
#>
[CmdletBinding()]
param( [Parameter(Mandatory=$true, ParameterSetName="buildall")]
       [Parameter(Mandatory=$true, ParameterSetName="pack")]
       [string]
       $BuildOutputPath = (Join-Path (Get-Location) BuildOutput),

       [Parameter(ParameterSetName="buildall")]
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

       [Parameter(ParameterSetName="CreateSettingsJson")]
       [switch]
       $CreateSettingsJson=$true,

       [Parameter(Mandatory=$true,ParameterSetName="buildall")]
       [Parameter(Mandatory=$true,ParameterSetName="pack")]
       [Parameter(Mandatory=$true,ParameterSetName="CreateSettingsJson")]
       [ValidateNotNullOrEmpty()]
       [string]$LlvmRoot = (Join-Path (Get-Location) llvm),

       [Parameter(ParameterSetName="buildall")]
       [ValidateNotNullOrEmpty()]
       [string]
       $BaseVsGenerator="Visual Studio 15 2017",

       [Parameter(ParameterSetName="pack")]
       [switch]$Pack,

       [Parameter(ParameterSetName="pack")]
       [ValidateNotNullOrEmpty()]
       [string]$PackOutputPath=(join-path (Get-Location) 'packages'),

       [Parameter(ParameterSetName="pack")]
       [ValidateNotNullOrEmpty()]
       [string]$NuspecOutputPath=(join-path (Get-Location) 'nuspec')
     )

function New-LlvmCmakeConfig([string]$platform, [string]$config, [string]$BaseGenerator, [string]$baseBuild, [string]$srcRoot )
{
    [CMakeConfig]$cmakeConfig = New-Object CMakeConfig -ArgumentList $platform, $config, $BaseGenerator, $baseBuild, $srcRoot
    $cmakeConfig.CMakeBuildVariables = @{
        LLVM_ENABLE_RTTI = "ON"
        LLVM_BUILD_TOOLS = "OFF"
        LLVM_BUILD_TESTS = "OFF"
        LLVM_BUILD_EXAMPLES = "OFF"
        LLVM_BUILD_DOCS = "OFF"
        LLVM_BUILD_RUNTIME = "OFF"
        LLVM_TARGETS_TO_BUILD  = "all"
        LLVM_USE_FOLDERS ="ON"
        CMAKE_INSTALL_PREFIX = "Install"
        CMAKE_CONFIGURATION_TYPES = $config
    }
    $errLogFile = "msbuild.$($cmakeConfig.Name).err.log"
    $fullLogFile = "msbuild.$($cmakeConfig.Name).log"
    $cmakeConfig.MsBuildCommandArgs = $cmakeConfig.MsBuildCommandArgs + @("/clp:verbosity=minimal", "/flp:verbosity=normal;LogFile=$fullLogFile", "/flp1:errorsonly;LogFile=$errLogFile")

    return $cmakeConfig
}

function Get-LlvmVersion( [string] $cmakeListPath )
{
    $props = @{}
    $matches = Select-String -Path $cmakeListPath -Pattern "set\(LLVM_VERSION_(MAJOR|MINOR|PATCH) ([0-9])+\)" |
        %{ $_.Matches } |
        %{ $props.Add( $_.Groups[1].Value, [Convert]::ToInt32($_.Groups[2].Value) ) }
    "$($props.Major).$($props.Minor).$($props.Patch)"
}

function BuildPlatformConfigPackage($platform, $config, $srcRoot, $buildOut, $version, $packOutputPath, $nuspecOutputPath)
{
    Write-Information "Generating Llvm.Libs.$platform-$config.nupkg"
    $properties = MakePropList @{ llvmsrcroot=$srcRoot
                                  llvmbuildroot=$buildOut
                                  version=$version
                                  platform=$platform
                                  configuration=$config
                                  nugetsrcdir=(Normalize-Path (Get-Location))
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
        foreach( $item in (Get-ChildItem -Path (join-path $buildOut "$platform-$config\$config\lib") -Filter "Llvm$arch*"))
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

    # generate nuget package from the generate nuspec
    $generatedNuSpec = join-path $nuspecOutputPath "Llvm.Libs.targets.$platform-$config.nuspec"
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

function BuildLibraries
{
param(
    [string] $BuildOutputPath,
    [switch] $Generate,
    [switch] $Build,
    [switch] $CreateSettingsJson,
    [string] $LlvmRoot,
    [string] $BaseVsGenerator,
    [CMakeConfig[]] $configurations
)

    $timer = [System.Diagnostics.Stopwatch]::StartNew()

    if( $Generate )
    {
        try
        {
            foreach( $config in $configurations )
            {
                Generate-CMake $config $LlvmRoot
            }
        }
        finally
        {
            Write-Information ("Total Generation Time: {0}" -f($timer.Elapsed.ToString()))
        }
    }

    if( $Build )
    {
        $buildTimer = [System.Diagnostics.Stopwatch]::StartNew()
        try
        {
            foreach( $config in $configurations )
            {
                Build-Cmake $config
            }
        }
        finally
        {
            $buildTimer.Stop()
            Write-Information ("Total Build Time: {0}" -f($buildTimer.Elapsed.ToString()))
        }
    }

    $timer.Stop()
    Write-Information ("Total Time: {0}" -f($timer.Elapsed.ToString()))
}

function BuildAndPackConfig($platform, $cmakeConfig)
{
    if( $platform = "AnyCPU" )
    {
        GenerateMultiPack $version $LlvmRoot $BuildOutputPath $PackOutputPath $NuspecOutputPath
    }
    else
    {
        BuildLibraries -BuildOutputPath $BuildOutputPath -Generate:$Generate -Build:$Build -Configurations @($cmakeConfig) -LlvmRoot $LlvmRoot -BaseVsGenerator $BaseVsGenerator
        BuildPlatformConfigPackage $Platform $Configuration $LlvmRoot $BuildOutputPath $version $PackOutputPath $NuspecOutputPath
    }
}


#--- Script scope setup
Set-StrictMode -Version Latest

. .\scripts\Common.ps1
. .\scripts\CmakeHelpers.ps1

#--- Main Script Body
# Force absolute paths for input params dealing in paths
$LlvmRoot = Normalize-Path $LlvmRoot
$BuildOutputPath = Normalize-Path $BuildOutputPath

Write-Information "LLVM Source Root: $LlvmRoot"

$cmakeListPath = Join-Path $LlvmRoot CMakeLists.txt
if( !( Test-Path -PathType Leaf $cmakeListPath ) )
{
    throw "'CMakeLists.txt' is missing, '$LlvmRoot' does not appear to be a valid source directory"
}

$version = (Get-LlvmVersion $cmakeListPath)

switch( $PsCmdlet.ParameterSetName )
{
    "build" {
        if( $Platform -eq "AnyCPU" )
        {
            GenerateMultiPack $version $LlvmRoot $BuildOutputPath $PackOutputPath $NuspecOutputPath
        }
        else
        {
            $cmakeConfigs = @(New-LlvmCmakeConfig $Platform $Configuration $BaseVsGenerator $BuildOutputPath $LlvmRoot)
            BuildLibraries -BuildOutputPath $BuildOutputPath -Generate:$Generate -Build:$Build -Configurations $cmakeConfigs -LlvmRoot $LlvmRoot -BaseVsGenerator $BaseVsGenerator
            BuildPlatformConfigPackage $Platform $Configuration $LlvmRoot $BuildOutputPath $version $PackOutputPath $NuspecOutputPath
        }
    }
    "buildall" {
        # Construct array of configurations to deal with
        $configurations = @( (New-LlvmCmakeConfig x86 "Release" $BaseVsGenerator $BuildOutputPath $LlvmRoot),
                             (New-LlvmCmakeConfig x86 "Debug" $BaseVsGenerator $BuildOutputPath $LlvmRoot),
                             (New-LlvmCmakeConfig x64 "Release" $BaseVsGenerator $BuildOutputPath $LlvmRoot),
                             (New-LlvmCmakeConfig x64 "Debug" $BaseVsGenerator $BuildOutputPath $LlvmRoot)
                           )

        BuildLibraries -BuildOutputPath $BuildOutputPath -Generate:$Generate -Build:$Build -Configurations $configurations -LlvmRoot $LlvmRoot -BaseVsGenerator $BaseVsGenerator
        foreach( $cfg in $configurations )
        {
            BuildPlatformConfigPackage $cfg. $config $srcRoot $buildOut $version $packOutputPath $nuspecOutputPath
        }
        BuildPlatformConfigPackages $LlvmRoot $BuildOutputPath $version $PackOutputPath $NuspecOutputPath
        GenerateMultiPack $version $LlvmRoot $BuildOutputPath $PackOutputPath $NuspecOutputPath
    }
    "pack" {
        BuildPlatformConfigPackages $LlvmRoot $BuildOutputPath $version $PackOutputPath $NuspecOutputPath
        GenerateMultiPack $version $LlvmRoot $BuildOutputPath $PackOutputPath $NuspecOutputPath
    }
    "CreateSettingsJson" {
        New-CmakeSettings $configurations | Out-File (join-path $LlvmRoot CMakeSettings.json)
    }
    default {
        throw "Unknown parameter set"
    }
}
