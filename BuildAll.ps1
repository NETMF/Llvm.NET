param( $startJob = $true )

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

function Invoke-msbuild([string]$project, [hashtable]$properties, [string[]]$targets, [string[]]$loggerArgs=@(),  [string[]]$additionalArgs=@())
{ 
    $msbuildArgs = @($project) + $loggerArgs + $additionalArgs + @("/t:$($targets -join ';')")
    if( $properties )
    {
        $msbuildArgs += @( "/p:$(ConvertTo-PropertyList $properties)" ) 
    }
    Write-Information "msbuild $($msbuildArgs -join ' ')"
    msbuild $msbuildArgs
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

function Get-BuildPaths( [string]$repoRoot)
{
    $buildPaths =  @{}
    $buildPaths.RepoRoot = $repoRoot
    $buildPaths.BuildOutputPath = Normalize-Path (Join-Path $repoRoot 'BuildOutput')
    $buildPaths.NugetRepositoryPath = Normalize-Path (Join-Path $buildPaths.BuildOutputPath 'packages')
    $buildPaths.NugetOutputPath = Normalize-Path (Join-Path $buildPaths.BuildOutputPath 'Nuget')
    $buildPaths.SrcRoot = Normalize-Path (Join-Path $repoRoot 'src')
    $buildPaths.LibLLVMSrcRoot = Normalize-Path (Join-Path $buildPaths.SrcRoot 'LibLLVM')
    $buildPaths.BuildTaskProjRoot = ([IO.Path]::Combine( $repoRoot, 'BuildExtensions', 'Llvm.NET.BuildTasks') )
    $buildPaths.BuildTaskProj = ([IO.Path]::Combine( $buildPaths.BuildTaskProjRoot, 'Llvm.NET.BuildTasks.csproj') )
    $buildPaths.BuildTaskBin = ([IO.Path]::Combine( $repoRoot, 'BuildOutput', 'bin', 'Release', 'net47', 'Llvm.NET.BuildTasks.dll') )
    return $buildPaths
}

function Get-BuildInformation($buildPaths) 
{
    pushd $buildPaths.RepoRoot
    try
    {
        Write-Information "Computing Build information"
        Add-Type -Path $buildPaths.BuildTaskBin
        $buildVersionData = [Llvm.NET.BuildTasks.BuildVersionData]::Load( (Join-Path $buildPaths.RepoRoot BuildVersion.xml ) )
        $semver = $buildVersionData.CreateSemVer(!!$env:APPVEYOR, !!$env:APPVEYOR_PULL_REQUEST_NUMBER, [DateTime]::UtcNow)
        
        return @{
           FullBuildNumber = $semVer.ToString($true)
           PackageVersion = $semVer.ToString($false)
           FileVersionMajor = $semVer.FileVersion.Major
           FileVersionMinor = $semVer.FileVersion.Minor
           FileVersionBuild = $semVer.FileVersion.Build
           FileVersionRevision = $semver.FileVersion.Revision
           FileVersion= "$($semVer.FileVersion.Major).$($semVer.FileVersion.Minor).$($semVer.FileVersion.Build).$($semVer.FileVersion.Revision)"
           LlvmVersion = "$($buildVersionData.AdditionalProperties['LlvmVersionMajor']).$($buildVersionData.AdditionalProperties['LlvmVersionMinor']).$($buildVersionData.AdditionalProperties['LlvmVersionPatch'])"
        }
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

function RunTheBuild
{
    $ScriptRoot = $args[0]
    cd $ScriptRoot
    $InformationPreference = 'Continue'
    $ErrorActionPreference = 'Stop'

    # setup standard MSBuild logging for this build
    $msbuildLoggerArgs = @('/clp:Verbosity=Minimal')

    if (Test-Path "C:\Program Files\AppVeyor\BuildAgent\Appveyor.MSBuildLogger.dll")
    {
        msbuildLoggerArgs.Add(" /logger:`"C:\Program Files\AppVeyor\BuildAgent\Appveyor.MSBuildLogger.dll`"")
    }

    $buildPaths = Get-BuildPaths $ScriptRoot

    Write-Information "Build Paths:"
    Write-Information ($buildPaths | Format-Table | Out-String)

    if( Test-Path -PathType Container $buildPaths.BuildOutputPath )
    {
        rd -Recurse -Force -Path $buildPaths.BuildOutputPath    
    }

    Write-Information "Restoring NUGET for internal build task"
    invoke-msbuild -Targets Restore -Project $buildPaths.BuildTaskProj -LoggerArgs $msbuildLoggerArgs

    Write-Information "Building internal build task and NuGetPackage"
    Invoke-MSBuild -Targets Build -Properties @{Configuration='Release';} -Project $buildPaths.BuildTaskProj -LoggerArgs $msbuildLoggerArgs

    $BuildInfo = Get-BuildInformation $buildPaths
    if($env:APPVEYOR)
    {
        Update-AppVeyorBuild -Version $BuildInfo.FullBuildNumber
    }
                                
    $packProperties = @{ version=$($BuildInfo.PackageVersion);
                         llvmversion=$($BuildInfo.LlvmVersion);
                         buildbinoutput=(normalize-path (Join-path $($buildPaths.BuildOutputPath) 'bin'));
                         configuration='Release'
                       }

    $msBuildProperties = @{ Configuration = 'Release';
                            FullBuildNumber = $BuildInfo.FullBuildNumber;
                            PackageVersion = $BuildInfo.PackageVersion;
                            FileVersionMajor = $BuildInfo.FileVersionMajor;
                            FileVersionMinor = $BuildInfo.FileVersionMinor;
                            FileVersionBuild = $BuildInfo.FileVersionBuild;
                            FileVersionRevision = $BuildInfo.FileVersionRevision;
                            FileVersion = $BuildInfo.FileVersion;
                            LlvmVersion = $BuildInfo.LlvmVersion;
                          }

    Write-Information "Build Parameters:"
    Write-Information ($BuildInfo | Format-Table | Out-String)

    # Need to invoke NuGet directly for restore of vcxproj as there is no /t:Restore target support
    Write-Information "Restoring Nuget Packages for LibLLVM.vcxproj"
    Invoke-NuGet restore src\LibLLVM\LibLLVM.vcxproj -PackagesDirectory $buildPaths.NuGetRepositoryPath

    Write-Information "Building LibLLVM"
    Invoke-MSBuild -Targets Build -Project src\LibLLVM\MultiPlatformBuild.vcxproj -Properties $msBuildProperties -LoggerArgs $msbuildLoggerArgs

    Write-Information "Restoring Nuget Packages for Llvm.NET"
    Invoke-MSBuild -Targets Restore -Project src\Llvm.NET\Llvm.NET.csproj -Properties $msBuildProperties -LoggerArgs $msbuildLoggerArgs

    Write-Information "Building Llvm.NET"
    Invoke-MSBuild -Targets Build -Project src\Llvm.NET\Llvm.NET.csproj -Properties $msBuildProperties -LoggerArgs $msbuildLoggerArgs

    Write-Information "Running Nuget Restore for Llvm.NET Tests"
    Invoke-MSBuild -Targets Restore -Project src\Llvm.NETTests\LLVM.NETTests.csproj -Properties $msBuildProperties -LoggerArgs $msbuildLoggerArgs

    Write-Information "Building Llvm.NET Tests"
    Invoke-MSBuild -Targets Build -Project src\Llvm.NETTests\LLVM.NETTests.csproj -Properties $msBuildProperties -LoggerArgs $msbuildLoggerArgs
}

if( $startJob )
{
    # Run entire build script as a separate 32bit job so that the build task DLL is loadable
    # and is unloaded after it completes. This, prevents "in use" errors when building the DLL
    # in VS for debugging/testing purposes. This uses a scriptblock to invoke the script with
    # $startJob param set to $false (blocking infinite recursion) 
    Start-Job -RunAs32 -ScriptBlock {
        try
        {
            invoke-expression "$($args[0]) `$false"
        }
        catch
        {
            Write-Error "ERROR: $( $error -join [Environment]::NewLine )"
        }
    } $sriptBlock -ArgumentList @($PSCommandPath) | Receive-Job -Wait -AutoRemoveJob
}
else
{
    RunTheBuild $PSScriptRoot
}