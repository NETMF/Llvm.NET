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

