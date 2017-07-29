$nativePlatforms="x64","Win32"
$configurations="Debug","Release"

function Invoke-Nuget
{
    #update system search path to include the directory of this script for nuget.exe
    $oldPath = $env:Path
    $env:Path = "$PSScriptRoot;$env:Path"
    try
    {
        $nugetPaths = where.exe nuget.exe 2>$null
        if( !$nugetPaths )
        {
            # Download it from official nuget release location
            Invoke-WebRequest -UseBasicParsing -Uri https://dist.nuget.org/win-x86-commandline/latest/nuget.exe -OutFile "$PSScriptRoot\nuget.exe"
        }

        nuget $args
    }
    finally
    {
        $env:Path = $oldPath
    }
}

function Normalize-Path([string]$path)
{
    $path = [System.IO.Path]::GetFullPath($path)
    if( !$path.EndsWith([System.IO.Path]::DirectorySeparatorChar) )
    {
        $path += [System.IO.Path]::DirectorySeparatorChar
    }
    return $path
}

# Set the buildNumber to a Nuget/NuSPec compatible Semantic version
#
# For details on the general algorithm used for computing the numbers here see:
# https://msdn.microsoft.com/en-us/library/system.reflection.assemblyversionattribute.assemblyversionattribute(v=vs.110).aspx 
# The only difference from the AssemblyVersionAttribute algorithm is that this
# uses UTC for the reference times, thus ensuring that all builds are consistent
# no matter what locale the build agent or developer machine is set up for.
#
$now = [DateTime]::Now
$midnightToday = New-Object DateTime( $now.Year,$now.Month,$now.Day,0,0,0,[DateTimeKind]::Utc)
$basedate = New-Object DateTime(2000,1,1,0,0,0,[DateTimeKind]::Utc)
$buildNum = [int]($now  - $basedate).Days
$buildRevision = [int]((($now - $midnightToday).TotalSeconds) / 2)
$env:FullBuildNumber = "4.0.$buildNum.$buildRevision-pre"

$buildOutputPath = Normalize-Path (Join-Path $PSScriptRoot "BuildOutput")
$nugetRepositoryPath = Normalize-Path (Join-Path $buildOutputPath "packages")
$nugetOutputPath = Normalize-Path (Join-Path $buildOutputPath "Nuget")
#$signedOutput = Normalize-Path (Join-Path $buildOutputPath "Signed")
$signedOutput = Normalize-Path (Join-Path $buildOutputPath "Unsigned")
$unsignedOutput = Normalize-Path (Join-Path $buildOutputPath "Unsigned")
$srcRoot = Normalize-Path (Join-Path $PSScriptRoot "src")
$libLLVMSrcRoot = Normalize-Path (Join-Path $srcRoot "LibLLVM")

$defaultPackProperties = "llvmversion=4.0.1;version=$env:FullBuildNumber;buildbinoutput=$signedOutput;buildcontentoutput=$unsignedOutput;configuration=Release"

if($env:APPVEYOR)
{
    Update-AppVeyorBuild -Version $env:FullBuildNumber
}

$loggerParams ="/clp:Verbosity=Minimal"
if( $env:APPVEYOR )
{
    $loggerParams='/logger:`"C:\Program Files\AppVeyor\BuildAgent\Appveyor.MSBuildLogger.dll`"'
}

Invoke-Nuget restore src\LibLLVM\LibLLVM.vcxproj -PackagesDirectory $nugetRepositoryPath

# native code doesn't have built-in multi-platform project builds like the new CPS based .NET projects do
foreach($platform in $nativePlatforms)
{
    foreach($config in $configurations)
    {
        Write-Information "Building LibLLVM $platform|$config"
        msbuild /p:Platform=$platform /p:Configuration=$config src\LibLLVM\LibLLVM.vcxproj $loggerParams
    }
}

Write-Information "Generating LibLLVM.NET.nupkg"
Invoke-Nuget pack src\NugetPkg\LibLLVM\LibLLVM.NET.nuspec -Properties "$defaultPackProperties;srcroot=$libLLVMSrcRoot" -OutputDirectory $nugetOutputPath

msbuild /t:Restore src\Llvm.NET\Llvm.NET.csproj $loggerParams

# multi-platform builds are built-in so only loop over config
foreach($config in $configurations )
{
    Write-Information "Building Llvm.NET $config"
    msbuild /p:Configuration=$config src\Llvm.NET\Llvm.NET.csproj $loggerParams
}

Write-Information "Generating LLVM.NET.nupkg"
Invoke-Nuget pack src\NugetPkg\LLVM.NET\LLVM.NET.nuspec -Properties $defaultPackProperties -OutputDirectory $nugetOutputPath
