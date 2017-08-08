
[CmdletBinding(SupportsShouldProcess)]
Param(
    [switch]$PackOnly,
    [ValidateSet('minimal', 'normal', 'detailed', 'diagnostic')]
    [string]$MsBuildVerbosity = 'minimal'
)

# Run entire build script as a separate job so that the build task
# DLL is unloaded after it completes. This, prevents "in use" errors
# when building the DLL in VS for debugging/testing purposes.

Start-Job -ScriptBlock {

    $PackOnly = $args[0].IsPresent
    $ScriptRoot = $args[1]
    $MsBuildVerbosity = $args[2]

    # pull in the utilities script
    . ([IO.Path]::Combine($ScriptRoot, 'BuildExtensions', 'BuildUtils.ps1'))

    # Top level try/catch to force script execution to stop on an error
    # Otherwise it might keep going depending on the ErrorPreferences setting
    # which could cause more problems, safer to just stop
    pushd $ScriptRoot
    try
    {
        $BuildInfo = Get-BuildInformation
        if(!$PackOnly)
        {
            if($env:APPVEYOR)
            {
                Update-AppVeyorBuild -Version $BuildInfo.FullBuildNumber
            }
        }
                                
        $packProperties = @{
            version=$($BuildInfo.PackageVersion);
            llvmversion=$($BuildInfo.LlvmVersion);
            buildbinoutput=(normalize-path (Join-path $($BuildInfo.BuildOutputPath) 'bin'));
            configuration='Release'
        }

        $msBuildProperties = @{ Configuration = 'Release';
                                FullBuildNumber = $BuildInfo.FullBuildNumber;
                                PackageVersion = $BuildInfo.PackageVersion;
                                FileVersionMajor = $BuildInfo.FileVersionMajor;
                                FileVersionMinor = $BuildInfo.FileVersionMinor;
                                FileVersionBuild = $BuildInfo.FileVersionBuild;
                                FileVersionRevision = $BuildInfo.FileVersionRevision;
                                LlvmVersion = $BuildInfo.LlvmVersion;
                                }

        Write-Information "Build Parameters:"
        Write-Information ($BuildInfo | Format-Table | Out-String)
    
        if(!$PackOnly)
        {
            Invoke-NuGet restore src\LibLLVM\LibLLVM.vcxproj -PackagesDirectory $BuildInfo.NuGetRepositoryPath

            # native code doesn't have built-in multi-platform project builds like the new CPS based .NET projects do
            foreach($platform in $BuildInfo.NativePlatforms)
            {
                Write-Information "Building LibLLVM"
                invoke-msbuild /t:Rebuild /p:Platform=$platform  "/p:$(ConvertTo-PropertyList $msBuildProperties)" src\LibLLVM\LibLLVM.vcxproj $BuildInfo.MsBuildArgs
            }
        }

        Write-Information "Generating LibLLVM.NET.nupkg"
        Invoke-NuGet pack src\NuGetPkg\LibLLVM\LibLLVM.NET.nuspec -NoPackageAnalysis -Properties (ConvertTo-PropertyList $packProperties) -OutputDirectory $BuildInfo.NuGetOutputPath

        if(!$PackOnly)
        {
            invoke-msbuild /t:Restore src\Llvm.NET\Llvm.NET.csproj "/p:$(ConvertTo-PropertyList $msBuildProperties)" $BuildInfo.MsBuildArgs

            # multi-platform builds are built-in so no loop
            Write-Information "Building Llvm.NET"
            invoke-msbuild /t:Rebuild src\Llvm.NET\Llvm.NET.csproj "/p:$(ConvertTo-PropertyList $msBuildProperties)" $BuildInfo.MsBuildArgs
        }
        Write-Information "Generating LLVM.NET.nupkg"
        Invoke-NuGet pack src\NuGetPkg\LLVM.NET\LLVM.NET.nuspec -NoPackageAnalysis -Properties (ConvertTo-PropertyList $packProperties) -OutputDirectory $BuildInfo.NuGetOutputPath
    }
    catch [Exception]
    {
        Write-Error $_
        return
    }
    finally
    {
        popd
    }
} -ArgumentList $PackOnly, $PSScriptRoot, $MsBuildVerbosity | Receive-Job -Wait -AutoRemoveJob
