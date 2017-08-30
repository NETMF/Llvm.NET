class CMakeConfig
{
    [string]$Name;
    [string]$Generator;
    [string]$ConfigurationType;
    [string]$BuildRoot;
    [string]$SrcRoot;
    [string[]]$CMakeCommandArgs;
    [string[]]$MsBuildCommandArgs;
    [hashtable]$CMakeBuildVariables;

    CMakeConfig([string]$platform, [string]$config, [string]$BaseGenerator, [string]$baseBuild, [string]$srcRoot)
    {
        $this.Generator = $BaseGenerator
        # normalize platform name and create final generator name
        $Platform = $Platform.ToLowerInvariant()
        switch($Platform)
        {
            "x86" {}
            "x64" {$this.Generator="$BaseGenerator Win64"}
            default { }
        }

        $this.Name="$platform-$config"
        $this.ConfigurationType = $config
        $this.BuildRoot = (Join-Path $baseBuild "$platform-$config")
        $this.SrcRoot = $srcRoot
        $this.CMakeCommandArgs = @()
        $this.MsBuildCommandArgs = @('/m')
        $this.CMakeBuildVariables = @{}
        if( $env:PROCESSOR_ARCHITECTURE -ieq "AMD64" )
        {
            $this.CMakeCommandArgs = "-Thost=x64"
        }
    }

    <#
    CMakeSettings.json uses an odd serialization form for the variables set.
    It is an array of hashtables with name and value properties
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
    into json with ConvertTo-Json works correctly.
    #>
    hidden [PSCustomObject] ToCMakeSettingsJsonifiable()
    {
        return [PSCustomObject]@{
            name = $this.Name
            generator = $this.Generator
            configurationType = $this.ConfigurationType
            buildRoot = $this.BuildRoot
            cmakeCommandArgs = $this.CMakeCommandArgs -join ' '
            buildCommandArgs = $this.MsBuildCommandArgs -join ' '
            variables = $this.GetVariablesForConversionToJson()
        }
    }
    
    #convert hashtable into an array of hash tables as needed by conversion to CMakeSettings.Json
    hidden [hashtable[]]GetVariablesForConversionToJson()
    {
        return $this.CMakeBuildVariables.GetEnumerator() | %{ @{name=$_.Key; value=$_.Value} }
    }
}

function Get-CmakeInfo([int]$minMajor, [int]$minMinor, [int]$minPatch)
{
    $cmakePaths = where.exe cmake.exe 2>$null
    if( !$cmakePaths )
    {
        throw "CMAKE.EXE not found - Version {0}.{1}.{2} or later is required and should be in the search path" -f($minMajor,$minMinor,$minPatch)
    }

    $cmakeInfo = cmake.exe -E capabilities | ConvertFrom-Json
    $cmakeVer = $cmakeInfo.version
    if( ($cmakeVer.major -lt $minMajor) -or ($cmakeVer.minor -lt $minMinor) -or ($cmakeVer.patch -lt $minPatch) )
    {
        throw "CMake version not supported. Found: {0}; Require >= {1}.{2}.{3}" -f($cmakeInfo.version.string,$minMajor,$minMinor,$minPatch)
    }
}

function Generate-CMake( [CMakeConfig]$config )
{
    # Verify Cmake version info
    $CmakeInfo = Get-CmakeInfo 3 7 1

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
        & cmake $cmakeArgs | %{Write-Progress -Activity $activity -PercentComplete (-1) -SecondsRemaining (-1) -Status ([string]$_) }

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

function Build-Cmake([CMakeConfig]$config)
{
    # Verify Cmake version info
    $CmakeInfo = Get-CmakeInfo 3 7 1

    Write-Information "CMake Buidling $($config.Name)"

    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    try
    {
        Write-Information "cmake --build $($config.BuildRoot) --config $($config.ConfigurationType) -- $($config.MsBuildCommandArgs -Join ' ')"
        cmake --build $config.BuildRoot --config $config.ConfigurationType -- $config.MsBuildCommandArgs
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

function New-CmakeSettings( [CMakeConfig[]]$configurations )
{
    ConvertTo-Json -Depth 4 ([PSCustomObject]@{ configurations = ( $configurations | %{$_.ToCMakeSettingsJsonifiable()} ) })
}