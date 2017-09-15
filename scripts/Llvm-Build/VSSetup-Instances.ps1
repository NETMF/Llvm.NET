# use VS provided PS Module to locate VS installed instances
function Find-VSInstance([switch]$PreRelease)
{
    Install-Module VSSetup -Scope CurrentUser | Out-Null
    Get-VSSetupInstance -Prerelease:$PreRelease |
        Select-VSSetupInstance -Require 'Microsoft.Component.MSBuild', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64', 'Microsoft.VisualStudio.Component.VC.CMake.Project' |
        select -First 1
}

function Find-MSBuild
{
    $foundOnPath = $true
    $msBuildPath = Find-OnPath msbuild.exe -ErrorAction Continue
    if( !$msBuildPath )
    {
        Write-Verbose "MSBuild not found attempting to locate VS installation"
        $vsInstall = Find-VSInstance
        if( !$vsInstall )
        {
            throw "MSBuild not found on PATH and No instances of VS found to use"
        }

        Write-Verbose "VS installation found: $vsInstall"
        $msBuildPath = [System.IO.Path]::Combine( $vsInstall.InstallationPath, 'MSBuild', '15.0', 'bin', 'MSBuild.exe')
        $foundOnPath = $false
    }

    if( !(Test-Path -PathType Leaf $msBuildPath ) )
    {
        Write-Verbose 'MSBuild not found'
        return $null
    }

    Write-Verbose "MSBuild Found at: $msBuildPath"
    return @{ FullPath=$msBuildPath
              BinPath=[System.IO.Path]::GetDirectoryName( $msBuildPath )
              FoundOnPath=$foundOnPath
            }
}
Export-ModuleMember -Function Find-MSBuild

function Invoke-MSBuild([string]$project, [hashtable]$properties, [string[]]$targets, [string[]]$loggerArgs=@(), [string[]]$additionalArgs=@())
{ 
    $oldPath = $env:Path
    try
    {
        $msbuildArgs = @($project, "/nr:false") + @("/t:$($targets -join ';')") + $loggerArgs + $additionalArgs
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
    finally
    {
        $env:Path = $oldPath
    }
}
Export-ModuleMember -Function Invoke-MSBuild

function Initialize-VCVars($vsInstance = (Find-VSInstance))
{
    if($vsInstance)
    {
        $vcEnv = Get-CmdEnvironment (Join-Path $vsInstance.InstallationPath 'VC\Auxiliary\Build\vcvarsall.bat') 'x86_amd64'
        Merge-Environment $vcEnv @('Prompt')
    }
    else
    {
        Write-Error "VisualStudio instance not found"
    }
}
