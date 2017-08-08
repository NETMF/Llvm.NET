# invokes nuget.exe, handles downloading it to the script root if it isn't already on the path
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
        Write-Information "nuget $args"
        nuget $args
        $err = $LASTEXITCODE
        if($err -ne 0)
        {
            throw "Error running nuget: $err"
        }
    }
    finally
    {
        $env:Path = $oldPath
    }
}

function Invoke-msbuild
{
    msbuild ($args -split ' ')
    if($LASTEXITCODE -ne 0)
    {
        throw "Error running msbuild: $LASTEXITCODE"
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

function Get-BuildInformation
{
    $repoRoot = Normalize-Path ( Join-Path $PSScriptRoot '..')
    pushd $repoRoot
    try
    {
        $BuildInfo =  @{}
        $BuildInfo.MsBuildArgs = [System.Collections.Generic.List[string]]::new()
        $BuildInfo.MsBuildArgs.Add("/clp:Verbosity=Minimal")
        $BuildInfo.NativePlatforms="x64","Win32"

        $BuildInfo.BuildOutputPath = Normalize-Path (Join-Path $repoRoot 'BuildOutput')
        $BuildInfo.NugetRepositoryPath = Normalize-Path (Join-Path $BuildInfo.BuildOutputPath 'packages')
        $BuildInfo.NugetOutputPath = Normalize-Path (Join-Path $BuildInfo.BuildOutputPath 'Nuget')
        $BuildInfo.SrcRoot = Normalize-Path (Join-Path $repoRoot 'src')
        $BuildInfo.LibLLVMSrcRoot = Normalize-Path (Join-Path $BuildInfo.SrcRoot 'LibLLVM')

        if (Test-Path "C:\Program Files\AppVeyor\BuildAgent\Appveyor.MSBuildLogger.dll")
        {
            $BuildInfo.MsBuildArgs.Add(" /logger:`"C:\Program Files\AppVeyor\BuildAgent\Appveyor.MSBuildLogger.dll`"")
        }

        $buildTaskProjRoot = ([IO.Path]::Combine( $repoRoot, 'BuildExtensions', 'Llvm.NET.BuildTasks') )
        $buildTaskProj = ([IO.Path]::Combine( $buildTaskProjRoot, 'Llvm.NET.BuildTasks.csproj') )
        $buildTaskBin = ([IO.Path]::Combine( $repoRoot, 'BuildOutput', 'Tasks', 'Llvm.NET.BuildTasks.dll') )
        if( !( Test-Path -PathType Leaf $buildTaskBin ) )
        {
            # generate the build task used for this build
            invoke-msbuild /t:Restore $buildTaskProj $BuildInfo.MsBuildArgs
            invoke-msbuild /t:Build /p:Configuration=Release $buildTaskProj $BuildInfo.MsBuildArgs
        }

        Add-Type -Path $buildTaskBin
        $buildVersionData = [Llvm.NET.BuildTasks.BuildVersionData]::Load( (Join-Path $repoRoot BuildVersion.xml ) )
        $semver = $buildVersionData.CreateSemVer(!!$env:APPVEYOR, !!$env:APPVEYOR_PULL_REQUEST_NUMBER)
        $BuildInfo.FullBuildNumber = $semVer.ToString($true)
        $BuildInfo.PackageVersion = $semVer.ToString($false)
        $BuildInfo.FileVersionMajor = $semVer.FileVersion.Major
        $BuildInfo.FileVersionMinor = $semVer.FileVersion.Minor
        $BuildInfo.FileVersionBuild = $semVer.FileVersion.Build
        $BuildInfo.FileVersionRevision = $semver.FileVersion.Revision
        $BuildInfo.LlvmVersion = $buildVersionData.LlvmVersion
 
        return $BuildInfo
    }
    finally
    {
        popd
    }
}

function ConvertTo-PropertyList([hashtable]$table)
{
    (($table.GetEnumerator() | %{ "$($_.Key)=$($_.Value)" }) -join ';')
}