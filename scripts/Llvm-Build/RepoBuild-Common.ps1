# Common functions shared via dot sourcing

function Update-Repository
{
    Write-Information "Updating submodules"
    git submodule update --init --recursive
}
Export-ModuleMember -Function Update-Repository

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
Export-ModuleMember -Function Find-OnPath

function ConvertTo-NormalizedPath([string]$path )
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
Export-ModuleMember -Function ConvertTo-NormalizedPath

function ConvertTo-PropList([hashtable]$hashTable)
{
    return ( $hashTable.GetEnumerator() | %{ @{$true=$_.Key;$false= $_.Key + "=" + $_.Value }[[string]::IsNullOrEmpty($_.Value) ] } ) -join ';'
}
Export-ModuleMember -Function ConvertTo-PropList

function Invoke-TimedBlock([string]$activity, [ScriptBlock]$block )
{
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    Write-Information "Starting: $activity"
    try
    {
        $block.Invoke()
    }
    finally
    {
        $timer.Stop()
        Write-Information "Finished: $activity - Time: $($timer.Elapsed.ToString())"
    }
}
Export-ModuleMember -Function Invoke-TimedBlock

<#
This is a workaround for https://github.com/PowerShell/PowerShell/issues/2736 
#>
function Format-Json([Parameter(Mandatory, ValueFromPipeline)][String] $json)
{
  $indent = 0;
  $srcLines = $json -Split "`n|`r`n|`r"

    foreach( $srcLine in $srcLines )
    {
        if ($srcLine -match '[\}\]]')
        {
            # This line contains  ] or }, decrement the indentation level
            $indent--
        }

        $line = (' ' * $indent * 2) + $srcLine.TrimStart().Replace(':  ', ': ')
        if ($srcLine -match '[\{\[]')
        {
            # This line contains [ or {, increment the indentation level
            $indent++
        }
        $line
    }
}
Export-ModuleMember -Function Format-Json

function Get-CmdEnvironment ($cmd, $Arguments)
{
    $retVal = @{}
    Write-Verbose "Running [`"$cmd`" $Arguments >nul & set] to get environment variables"
    $envOut =  cmd /c "`"$cmd`" $Arguments >nul & set"
    $envout | Out-File 'envout.txt'
    foreach( $line in $envOut ) 
    { 
        $name, $value = $line.split('=');
        $retVal.Add($name, $value)
    }
    return $retVal
}
Export-ModuleMember -Function Get-CmdEnvironment

function Merge-Environment( [hashtable]$OtherEnv, [string[]]$IgnoreNames )
{
<#
.SYNOPSIS
    Merges the name value pairs of a hash table into the current environment

.PARAMETER OtherEnv
    Hash table containing name value pairs to add to the environment

.PARAMETER IgnoreNames
    Names of properties in OtherEnv to ignore
.NOTES
    Standard system variables are always ignored and are blocked from merging
#>
    $SystemVars = @('COMPUTERNAME',
                    'USERPROFILE',
                    'HOMEPATH',
                    'LOCALAPPDATA',
                    'PSModulePath',
                    'PROCESSOR_ARCHITECTURE',
                    'CommonProgramFiles(x86)',
                    'ProgramFiles(x86)',
                    'PROCESSOR_LEVEL',
                    'LOGONSERVER',
                    'SystemRoot',
                    'SESSIONNAME',
                    'ALLUSERSPROFILE',
                    'PUBLIC',
                    'APPDATA',
                    'PROCESSOR_REVISION',
                    'USERNAME',
                    'CommonProgramW6432',
                    'CommonProgramFiles',
                    'OS',
                    'USERDOMAIN_ROAMINGPROFILE',
                    'PROCESSOR_IDENTIFIER',
                    'ComSpec',
                    'SystemDrive',
                    'ProgramFiles',
                    'NUMBER_OF_PROCESSORS',
                    'ProgramData',
                    'ProgramW6432',
                    'windir',
                    'USERDOMAIN'
                   )
    $IgnoreNames += $SystemVars
    $otherEnv.GetEnumerator() | ?{ !($ignoreNames -icontains $_.Name) } | %{ Set-Item -Path "env:$($_.Name)" -value $_.Value; Write-Verbose "env:$($_.Name)=$($_.Value)" }
}
Export-ModuleMember -Function Merge-Environment

