
[CmdletBinding(SupportsShouldProcess)]
Param(
    [Parameter()]
    [ValidateSet('minimal', 'normal', 'detailed', 'diagnostic')]
    [string]$MsBuildVerbosity = 'minimal'
)

"outer root: $PSScriptRoot"

# Run entire builds script as a separate job so that the build task
# DLL is unloaded after it completes. This, prevents "in use" errors
# when building the DLL in VS for debugging/testing purposes.

Start-Job -ArgumentList @($PSScriptRoot, $MsBuildVerbosity) -ScriptBlock {

    param([string]$ScriptRoot, [string]$MsBuildVerbosity)

    # pull in the utilities script
    . ([IO.Path]::Combine($ScriptRoot, 'BuildExtensions', 'BuildUtils.ps1'))

    # Top level try/catch to force script execution to stop on an error
    # Otherwise it might keep going depending on the ErrorPreferences setting
    # which could cause more problems, safer to just stop
    try
    {
        $BuildInfo =  @{}
        $BuildInfo.MsBuildArgs = [System.Collections.Generic.List[string]]::new()
        $BuildInfo.MsBuildArgs.Add("/clp:Verbosity=Minimal")
        $BuildInfo.NativePlatforms="x64","Win32"

        $BuildInfo.BuildOutputPath = Normalize-Path (Join-Path $ScriptRoot 'BuildOutput')
        $BuildInfo.NugetRepositoryPath = Normalize-Path (Join-Path $BuildInfo.BuildOutputPath 'packages')
        $BuildInfo.NugetOutputPath = Normalize-Path (Join-Path $BuildInfo.BuildOutputPath 'Nuget')
        $BuildInfo.SrcRoot = Normalize-Path (Join-Path $ScriptRoot 'src')
        $BuildInfo.LibLLVMSrcRoot = Normalize-Path (Join-Path $BuildInfo.SrcRoot 'LibLLVM')

        if (Test-Path "C:\Program Files\AppVeyor\BuildAgent\Appveyor.MSBuildLogger.dll")
        {
            $BuildInfo.MsBuildArgs.Add(" /logger:`"C:\Program Files\AppVeyor\BuildAgent\Appveyor.MSBuildLogger.dll`"")
        }

        $buildTaskProjRoot = ([IO.Path]::Combine( $ScriptRoot, 'BuildExtensions', 'Llvm.NET.BuildTasks') )
        $buildTaskProj = ([IO.Path]::Combine( $buildTaskProjRoot, 'Llvm.NET.BuildTasks.csproj') )
        $buildTaskBin = ([IO.Path]::Combine( $ScriptRoot, 'BuildOutput', 'Tasks', 'Llvm.NET.BuildTasks.dll') )
        if( !( Test-Path -PathType Leaf $buildTaskBin ) )
        {
            # generate the build task used for this build
            invoke-msbuild /t:Restore $buildTaskProj $BuildInfo.MsBuildArgs
            invoke-msbuild /t:Build /p:Configuration=Release $buildTaskProj $BuildInfo.MsBuildArgs
        }

        Add-Type -Path $buildTaskBin
        $buildVersionData = [Llvm.NET.BuildTasks.BuildVersionData]::Load( (Join-Path $ScriptRoot BuildVersion.xml ) )
        $semver = $buildVersionData.CreateSemVer($true,$true)
        $semver.ToString()
        $semver.ToString($true)
        $buildVersionData
        return

        if($env:APPVEYOR)
        {
            Update-AppVeyorBuild -Version $BuildInfo.FullBuildNum
        }

        $BuildInfo.DefaultPackProperties = "llvmversion=$($BuildInfo.LlvmVersion);version=$($BuildInfo.FullBuildNumber);buildbinoutput=$($BuildInfo.BuildOutputPath);buildcontentoutput=$($BuildInfo.BuildOutputPath);configuration=Release"

        Write-Information "Build Parameters:"
        Write-Information ($BuildInfo | Format-Table | Out-String)
    
        Invoke-Nuget restore src\LibLLVM\LibLLVM.vcxproj -PackagesDirectory $BuildInfo.NugetRepositoryPath

        # native code doesn't have built-in multi-platform project builds like the new CPS based .NET projects do
        foreach($platform in $BuildInfo.NativePlatforms)
        {
            Write-Information "Building LibLLVM"
            invoke-msbuild /p:Platform=$platform src\LibLLVM\LibLLVM.vcxproj $BuildInfo.MsBuildArgs
        }

        #Write-Information "Generating LibLLVM.NET.nupkg"
        #Invoke-NuGet pack src\NugetPkg\LibLLVM\LibLLVM.NET.nuspec -Properties "$($BuildInfo.DefaultPackProperties);srcroot=$($BuildInfo.FibLLVMSrcRoot)" -OutputDirectory $BuildInfo.NugetOutputPath

        invoke-msbuild /t:Restore src\Llvm.NET\Llvm.NET.csproj $BuildInfo.MsBuildArgs

        # multi-platform builds are built-in so no loop
        Write-Information "Building Llvm.NET"
        invoke-msbuild src\Llvm.NET\Llvm.NET.csproj $BuildInfo.MsBuildArgs

        Write-Information "Generating LLVM.NET.nupkg"
        Invoke-Nuget pack src\NugetPkg\LLVM.NET\LLVM.NET.nuspec -Properties $BuildInfo.DefaultPackProperties -OutputDirectory $BuildInfo.NugetOutputPath
    }
    catch [Exception]
    {
        Write-Error $_
        return
    }
} | Receive-Job -Wait -AutoRemoveJob
