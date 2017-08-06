class CSemVerPreReleaseVersion
{
    CSemVerPreReleaseVersion([int]$preReleaseNameIndex, [int]$preReleaseNumber, [int]$preReleaseFix)
    {
        $this.PreReleaseNameIndex = $preReleaseNameIndex
        $this.PrereleaseNumber = $preReleaseNumber
        $this.PrereleaseFix = $preReleaseFix        
    }

    [ValidateRange(0,7)]
    [int] $PreReleaseNameIndex;

    [ValidateRange(0,99)]
    [int] $PrereleaseNumber;

    [ValidateRange(0,99)]
    [int] $PrereleaseFix;

    [string] ToString([bool]$fullName = $false)
    {
        $bldr = [System.Text.StringBuilder]::new("-")
        $bldr.Append( $this.GetPreReleaseName($fullName) )
        if($this.PrereleaseNumber -gt 0)
        {
            $bldr.Append(".$($this.PrereleaseNumber)")
            if($this.PrereleaseFix -gt 0)
            {
                $bldr.Append(".$($this.PrereleaseFix)")
            }
        }
        return $bldr.ToString()
    }

    [string] GetPreReleaseName([bool]$fullName = $false )
    {
        if( $this.PreReleaseNameIndex -lt 0 )
        {
            return $null
        }

        $name = @( 'alpha', 'beta', 'delta', 'epsilon', 'gamma', 'kappa', 'prerelease', 'rc')[$this.PreReleaseNameIndex] 
        if( !$fullName )
        {
            return $name[0]
        }
        else
        {
            return $name
        }
    }

}

class CSemVer
{   
    [ValidateRange(0,99999)]
    [int] $Major;

    [ValidateRange(0,49999)]
    [int] $Minor;

    [ValidateRange(0,9999)]
    [int] $Patch;

    [CSemVerPreReleaseVersion]$PreReleaseVersion;

    [ValidateLength(0,20)]
    [string]$BuildMetadata;

    CSemVer([int]$major, [int]$minor, [int]$patch)
    {
        $this.Major = $major
        $this.Minor = $minor
        $this.Patch = $patch
        $this.PreReleaseVersion = $null
    }

    [string] ToString([bool]$fullName=$false)
    {
        $bldr = [System.Text.StringBuilder]::new("$($this.Major).$($this.Minor).$($this.Patch)")
        if( !$this.PreReleaseVersion )
        {
            $bldr.Append($this.PreReleaseVersion.ToString($fullName))
        }

        if($this.BuildMetadata)
        {
            $bldr.Append("+$($this.BuildMetadata)")
        }
        return $bldr.ToString()
    }

    [Version] GetFileVersion()
    {
        $orderedNum = $this.GetOrderedVersion() -shl 1
        
        $fileRevision = $orderedNum % 65536
        $rem = ($orderedNum - $fileRevision) / 65536
        
        $fileBuild = $rem % 65536
        $rem = ($rem - $fileBuild) / 65536
        
        $fileMinor = $rem % 65536
        $rem = ($rem - $fileMinor) / 65536
        
        $fileMajor = $rem % 65536

        return [Version]::new($fileMajor, $fileMinor, $fileBuild, $fileRevision)
    }

    [UInt64] GetOrderedVersion()
    {
        $mulNum = 100 
        $mulName = $mulNum * 100
        $mulPatch = ($mulName * 8) + 1
        $mulMinor = $mulPatch * 10000
        $mulMajor = $mulMinor * 50000

        $retVal = ($this.Major * $mulMajor) + ($this.Minor * $mulMinor) + (($this.Patch + 1) * $mulPatch) 
        if($this.PreReleaseNameIndex -ge 0)
        {
            $retVal -= $mulPatch - 1
            $retVal += $this.PreReleaseNameIndex * $mulName
            $retVal += $this.PrereleaseNumber * $mulNum
            $retVal += $this.PrereleaseFix
        }
        return $retVal
    }
}


