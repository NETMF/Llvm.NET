function Find-Python
{
    # Find/Install Python
    $pythonExe = Find-OnPath 'python.exe'
    $foundOnPath = $false
    if($pythonExe)
    {
        $pythonPath = [System.IO.Path]::GetDirectoryName($pythonExe)
        $foundOnPath = $true
    }
    else
    {
        # try registry location(s) see [PEP-514](https://www.python.org/dev/peps/pep-0514/)
        if( Test-Path -PathType Container HKCU:Software\Python\*\2.7\InstallPath )
        {
            $pythonPath = dir HKCU:\Software\Python\*\2.7\InstallPath | ?{ Test-Path -PathType Leaf (Join-Path ($_.GetValue($null)) 'python.exe') } | %{ $_.GetValue($null) } | select -First 1
        }
        elif( Test-Path -PathType Container HKLM:Software\Python\*\2.7\InstallPath )
        {
            $pythonPath = dir HKLM:\Software\Python\*\2.7\InstallPath | ?{ Test-Path -PathType Leaf (Join-Path ($_.GetValue($null)) 'python.exe') } | %{ $_.GetValue($null) } | select -First 1
        }
        elif ( Test-Path -PathType Container HKLM:Software\Wow6432Node\Python\*\2.7\InstallPath )
        {
            $pythonPath = dir HKLM:\Software\Wow6432Node\Python\*\2.7\InstallPath | ?{ Test-Path -PathType Leaf (Join-Path ($_.GetValue($null)) 'python.exe') } | %{ $_.GetValue($null) } | select -First 1
        }

        if( !$pythonPath )
        {
            return $null
        }
        $pythonExe = Join-Path $pythonPath 'python.exe'
    }

    return @{ FullPath = $pythonExe
              BinPath = $pythonPath
              FoundOnPath = $foundOnPath
            }
}
Export-ModuleMember -Function Find-Python

function Install-Python
{
    param([string]$PythonPath = (Join-Path (Get-ToolsPath) 'Python27'))

    # Download installer from official Python release location
    $msiPath = (Join-Path (Get-ToolsPath) 'python-2.7.13.msi')
    Write-Information 'Downloading Python'
    Invoke-WebRequest -UseBasicParsing -Uri https://www.python.org/ftp/python/2.7.13/python-2.7.13.msi -OutFile $msiPath

    Write-Information 'Installing Python'
    msiexec /i  $msiPath "TARGETDIR=$PythonPath" /qn | Out-Null
    return $PythonPath
}
Export-ModuleMember -Function Install-Python

# invokes NuGet.exe, handles downloading it to the script root if it isn't already on the path
function Invoke-NuGet
{
    $NuGetPaths = Find-OnPath NuGet.exe -ErrorAction Continue
    if( !$NuGetPaths )
    {
        $nugetToolsPath = "$($RepoInfo.ToolsPath)\NuGet.exe"
        if( !(Test-Path $nugetToolsPath))
        {
            # Download it from official NuGet release location
            Write-Verbose "Downloading Nuget.exe to $nugetToolsPath"
            Invoke-WebRequest -UseBasicParsing -Uri https://dist.NuGet.org/win-x86-commandline/latest/NuGet.exe -OutFile $nugetToolsPath
        }
    }
    Write-Information "NuGet $args"
    NuGet $args
    $err = $LASTEXITCODE
    if($err -ne 0)
    {
        throw "Error running NuGet: $err"
    }
}
Export-ModuleMember -Function Invoke-NuGet

function Expand-ArchiveStream([Parameter(Mandatory=$true, ValueFromPipeLine)]$src, [Parameter(Mandatory=$true)]$OutputPath)
{
    $zipArchive = [System.IO.Compression.ZipArchive]::new($src)
    [System.IO.Compression.ZipFileExtensions]::ExtractToDirectory( $zipArchive, $OutputPath)
}

function Download-AndExpand([Parameter(Mandatory=$true, ValueFromPipeLine)]$uri, [Parameter(Mandatory=$true)]$OutputPath)
{
    $strm = (Invoke-WebRequest -UseBasicParsing -Uri $uri).RawContentStream
    Expand-ArchiveStream $strm $OutputPath
}
