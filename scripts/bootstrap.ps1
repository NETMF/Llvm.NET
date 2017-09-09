. (Join-Path $PSScriptRoot 'common.ps1')

if( $env:APPVEYOR )
{
    $global:InformationPreference="Continue"
    $global:ErrorActionPreference="Continue"
}

# ensure the output locations exist
$ToolsPath = Get-ToolsPath
$NuspecOutputPath = Get-NuspecPath

$env:Path = "$ToolsPath;$env:Path"
$NuGetExePath = Find-OnPath NuGet.exe -ErrorAction Continue
if( !$NuGetExePath )
{
    # Download it from official NuGet release location
    Invoke-WebRequest -UseBasicParsing -Uri https://dist.NuGet.org/win-x86-commandline/latest/NuGet.exe -OutFile (Join-Path $ToolsPath 'NuGet.exe')
}

# Install Python
$python = Find-OnPath 'python.exe'
if(!$python)
{
    # Download installer from official Python release location
    $msiPath = (Join-Path $ToolsPath 'python-2.7.13.msi')
    Write-Information 'DOwnloading Python'
    Invoke-WebRequest -UseBasicParsing -Uri https://www.python.org/ftp/python/2.7.13/python-2.7.13.msi -OutFile $msiPath

    Write-Information 'Installing Python'
    msiexec /i  $msiPath "TARGETDIR=$(Join-Path $ToolsPath 'Python27')" /qn
}

# Install CMake - https://cmake.org/files/v3.9/cmake-3.9.2-win64-x64.msi OR https://cmake.org/files/v3.9/cmake-3.9.2-win32-x86.msi
$cmake = Find-OnPath 'cmake.exe'
if(!$cmake)
{
    if( [Environment]::Is64BitOperatingSystem )
    {
        $cmakeMsiName = 'cmake-3.9.2-win64-x64.msi'
    }
    else
    {
        $cmakeMsiName = 'cmake-3.9.2-win32-x86.msi'
    }

    # Download installer from official cmake release location
    $msiPath = (Join-Path $ToolsPath $cmakeMsiName)
    Write-Information 'Downloading cmake'
    Invoke-WebRequest -UseBasicParsing -Uri "https://cmake.org/files/v3.9/$cmakeMsiName" -OutFile $msiPath

    Write-Information 'Installing cmake'
    msiexec /i  $msiPath "TARGETDIR=$(Join-Path $ToolsPath 'CMake')" 'ADD_CMAKE_TO_PATH="None"' 'DESKTOP_SHORTCUT_REQUESTED=0' /quiet /qn /norestart
}

# TODO: (maybe) if VSinstance not found with C++ and CMAke support - download and install those... (anyone using these libs should already have those
#       and it can be a big install so best left to user to install them.)

$msBuildInfo = Find-MsBuild
if( !$msBuildInfo )
{
    throw "MSBuild was not found"
}

if( !$msBuildInfo.FoundOnPath )
{
    $env:Path="$($msBuildInfo.BinPath);$env:Path"
}
