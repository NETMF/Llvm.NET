class CMakeConfig
{
    [string]$Name;

    [ValidateSet('x86','x64')]
    [string]$Platform;

    [ValidateSet('Debug','Release')]
    [string]$Configuration;

    [string]$BuildRoot;
    [string]$SrcRoot;
    [string]$Generator;
    [string[]]$CMakeCommandArgs;
    [string[]]$BuildCommandArgs;
    [string[]]$InheritEnvironments;
    [hashtable]$CMakeBuildVariables;

    CMakeConfig([string]$plat, [string]$config, [string]$baseBuild, [string]$srcRoot)
    {
        $this.Generator = "Ninja"
        $this.Platform = $Plat.ToLowerInvariant()
        $this.InheritEnvironments = "msvc_$()"
        switch($this.Platform)
        {
            "x86" {$this.InheritEnvironments = @("msvc_x86")}
            "x64" {$this.InheritEnvironments = @("msvc_x64")}
            default { }
        }

        $this.Name="$($this.Platform)-$config"
        $this.Configuration = $config;
        $this.BuildRoot = Join-Path $baseBuild $this.Name
        $this.SrcRoot = $srcRoot
        $this.CMakeCommandArgs = @()
        $this.BuildCommandArgs = @()
        $this.CMakeBuildVariables = @{}
    }

    <#
    CMakeSettings.json uses an odd serialization form for the variables set.
    It is an array of hash tables with name and value properties
    e.g.:
    [
        {
            "value":  "boo",
            "name":  "baz"
        },
        {
            "value":  "bar",
            "name":  "foo"
        }
    ]
    instead of say:
    {
        "baz":  "boo",
        "foo":  "bar"
    }
    This is likely due to deserializing to a strong type, though there are ways
    to do that and keep the simpler form. This method deals with that by doing
    a conversion to a custom object with the variables nested such that conversion
    into json with ConvertTo-Json works correctly. This also filters the properties
    to only those used in the JSON file.
    #>
    hidden [hashtable] ToCMakeSettingsJsonifiable()
    {
        $baseBuild = ConvertTo-NormalizedPath ([System.IO.Path]::GetDirectoryName($this.BuildRoot))
        return @{
            name = $this.Name
            generator = $this.Generator
            inheritEnvironments = $this.InheritEnvironments
            configurationType = @($this.Configuration, 'RelWithDebInfo')[[int]( $this.Configuration -ieq "Release" )]
            buildRoot = "$baseBuild`${name}"
            cmakeCommandArgs = $this.CMakeCommandArgs -join ' '
            buildCommandArgs = $this.BuildCommandArgs -join ' '
            ctestCommandArgs = ''
            variables = $this.GetVariablesForConversionToJson()
        }
    }

    #convert hashtable into an array of hash tables as needed by conversion to CMakeSettings.Json
    hidden [hashtable[]]GetVariablesForConversionToJson()
    {
        return $this.CMakeBuildVariables.GetEnumerator() | %{ @{name=$_.Key; value=$_.Value} }
    }
}

function Assert-CmakeInfo([Version]$minVersion)
{
    $cmakePaths = where.exe cmake.exe 2>$null
    if( !$cmakePaths )
    {
        throw "CMAKE.EXE not found"
    }

    $cmakeInfo = cmake.exe -E capabilities | ConvertFrom-Json
    $cmakeVer = [Version]::new($cmakeInfo.version.major,$cmakeInfo.version.minor,$cmakeInfo.version.patch)
    if( $cmakeVer -lt $minVersion )
    {
        throw "CMake version not supported. Found: $cmakeVer; Require >= $($minVersion)"
    }

    if( !($cmakeInfo.version.string.Contains('MSVC') ) )
    {
        throw "This build requires the MSVC specific version of cmake (included with the VC build tools)"
    }
}
Export-ModuleMember -Function Assert-CmakeInfo

function Invoke-CMakeGenerate( [CMakeConfig]$config )
{
    # Verify Cmake version info
    Assert-CmakeInfo ([Version]::new(3, 7, 1))

    $activity = "Generating solution for $($config.Name)"
    Write-Information $activity
    if(!(Test-Path -PathType Container $config.BuildRoot ))
    {
        New-Item -ItemType Container $config.BuildRoot | Out-Null
    }

    # Construct full set of args from fixed options and configuration variables
    $cmakeArgs = New-Object System.Collections.ArrayList
    $cmakeArgs.Add("-G`"$($config.Generator)`"" ) | Out-Null
    foreach( $param in $config.CMakeCommandArgs )
    {
        $cmakeArgs.Add( $param ) | Out-Null
    }

    foreach( $var in $config.CMakeBuildVariables.GetEnumerator() )
    {
        $cmakeArgs.Add( "-D$($var.Key)=$($var.Value)" ) | Out-Null
    }

    $cmakeArgs.Add( $config.SrcRoot ) | Out-Null

    pushd $config.BuildRoot
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    try
    {
        Write-Verbose "cmake $cmakeArgs"
        & cmake $cmakeArgs #| %{Write-Progress -Activity $activity -PercentComplete (-1) -SecondsRemaining (-1) -Status ([string]$_) }

        if($LASTEXITCODE -ne 0 )
        {
            throw "Cmake generation exited with non-zero exit code: $LASTEXITCODE"
        }
    }
    finally
    {
        $timer.Stop()
        Write-Progress -Activity $activity -Completed
        Write-Verbose "Generation Time: $($timer.Elapsed.ToString())"
        popd
    }
}
Export-ModuleMember -Function Generate-CMake

function Invoke-CmakeBuild([CMakeConfig]$config)
{
    # Verify Cmake version info
    Assert-CmakeInfo ([Version]::new(3, 7, 1))

    Write-Information "CMake Building $($config.Name)"

    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    try
    {
        Write-Verbose "cmake --build $config.BuildRoot --config $config.Configuration -- $config.BuildCommandArgs"
        cmake --build $config.BuildRoot --config $config.Configuration -- $config.BuildCommandArgs
        if($LASTEXITCODE -ne 0 )
        {
            throw "Cmake build exited with non-zero exit code: $LASTEXITCODE"
        }
    }
    finally
    {
        $timer.Stop()
        Write-Information "Build Time: $($timer.Elapsed.ToString())"
    }
}
Export-ModuleMember -Function Build-CMake

function New-CmakeSettings( [Parameter(Mandatory, ValueFromPipeline)][CMakeConfig] $configuration )
{
    BEGIN
    {
        $convertedSettings = [System.Collections.Generic.List[hashtable]]::new( )
    }
    PROCESS
    {
        $convertedSettings.Add( $configuration.ToCMakeSettingsJsonifiable( ) )
    }
    END
    {
        ConvertTo-Json -Depth 4 @{ configurations = $convertedSettings }
    }
}
Export-ModuleMember -Function New-CmakeSettings

function Assert-CMakeList([Parameter(Mandatory=$true)][string] $root)
{
    $cmakeListPath = Join-Path $root CMakeLists.txt
    if( !( Test-Path -PathType Leaf $cmakeListPath ) )
    {
        throw "'CMakeLists.txt' is missing, '$root' does not appear to be a valid source directory"
    }
}
Export-ModuleMember -Function Assert-CMakeList
