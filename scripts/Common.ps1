# Common functions shared via dot sourcing

function Get-ToolsPath
{
    $toolsPath = $([System.IO.Path]::Combine($PSScriptRoot, '..', 'tools'))
    if( !(Test-Path -PathType Container $toolsPath) )
    {
        return md $toolsPath
    }
}

function Get-NuspecPath
{
    $toolsPath = $([System.IO.Path]::Combine($PSScriptRoot, '..', 'nuspec'))
    if( !(Test-Path -PathType Container $toolsPath) )
    {
        return md $toolsPath
    }
}

function Find-OnPath
{
    [CmdletBinding()]
    Param( [Parameter(Mandatory=$True,Position=0)][string]$exeName)
    $path = where.exe $exeName 2>$null
    if(!$path)
    {
        Write-Verbose "'$exeName' not found on PATH"
    }
    else
    {
        Write-Verbose "Found: '$path'"
    }
    return $path
}

# invokes NuGet.exe, handles downloading it to the script root if it isn't already on the path
function Invoke-NuGet
{
    $NuGetPaths = Find-OnPath NuGet.exe -ErrorAction Continue
    if( !$NuGetPaths )
    {
        # Download it from official NuGet release location
        Invoke-WebRequest -UseBasicParsing -Uri https://dist.NuGet.org/win-x86-commandline/latest/NuGet.exe -OutFile "$PSScriptRoot\NuGet.exe"
    }
    Write-Information "NuGet $args"
    NuGet $args
    $err = $LASTEXITCODE
    if($err -ne 0)
    {
        throw "Error running NuGet: $err"
    }
}

function Find-VSInstance
{
    Install-Module VSSetup -Scope CurrentUser | Out-Null
    return Get-VSSetupInstance -All | select -First 1
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

function Invoke-msbuild([string]$project, [hashtable]$properties, [string[]]$targets, [string[]]$loggerArgs=@(), [string[]]$additionalArgs=@())
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

function Normalize-Path([string]$path )
{
    if(![System.IO.Path]::IsPathRooted($path))
    {
        $path = [System.IO.Path]::Combine((pwd).Path,$path)
    }

    $path = [System.IO.Path]::GetFullPath($path)
    if( !$path.EndsWith([System.IO.Path]::DirectorySeparatorChar) -and !$path.EndsWith([System.IO.Path]::AltDirectorySeparatorChar))
    {
        $path = $path + [System.IO.Path]::DirectorySeparatorChar
    }
    return $path
}

function MakePropList([hashtable]$hashTable)
{
    return ( $hashTable.GetEnumerator() | %{ @{$true=$_.Key;$false= $_.Key + "=" + $_.Value }[[string]::IsNullOrEmpty($_.Value) ] } ) -join ';'
}