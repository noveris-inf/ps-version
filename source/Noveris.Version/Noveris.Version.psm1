<#
#>

################
# Global settings
$ErrorActionPreference = "Stop"
$InformationPreference = "Continue"
Set-StrictMode -Version 2.0

########
# Script variables
$semVerPattern = "^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$"

<#
#>
Function Get-BuildNumber {
    [OutputType('System.Int64')]
    [CmdletBinding()]
    param(
    )

    process
    {
        $MinDate = New-Object DateTime -ArgumentList 1970, 1, 1
        [Int64]([DateTime]::Now - $MinDate).TotalDays
    }
}

<#
#>
Function Select-ValidVersions
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Source,

        [Parameter(Mandatory=$false)]
        [switch]$First = $false,

        [Parameter(Mandatory=$false)]
        [switch]$Required = $false
    )

    begin
    {
        $MatchFound = $false
    }

    process
    {
        if ([string]::IsNullOrEmpty($Source))
        {
            Write-Verbose "Null or empty version supplied"
            return
        }

        if ($MatchFound -and $First)
        {
            Write-Verbose "Ignoring source - valid version already identified and -First specified"
            return
        }

        Write-Verbose "Processing Version Source: ${Source}"
        $working = $Source

        # Strip any refs/tags/ reference at the beginning of the version source
        $tagBranch = "refs/tags/"
        if ($working.StartsWith($tagBranch))
        {
            Write-Verbose "Version starts with refs/tags format - Removing"
            $working = $working.Substring($tagBranch.Length)
        }

        # Save a copy of the raw version, minus the leading refs/tags, if it existed, as the tag
        $tag = $working

        # Leading 'v' should be stripped for SemVer processing
        if ($working.StartsWith("v"))
        {
            Write-Verbose "Version starts with 'v' - Removing"
            $working = $working.Substring(1)
        }

        # Check if we match the semver regex pattern
        # Regex used directly from semver.org
        if ($working -notmatch $semVerPattern)
        {
            Write-Verbose "Version string not in correct format. skipping"
            return
        }

        # Extract components of version string
        $major = [Convert]::ToInt32($Matches[1])
        $minor = [Convert]::ToInt32($Matches[2])
        $patch = [Convert]::ToInt32($Matches[3])
        $Prerelease = $Matches[4]
        $Buildmetadata = $Matches[5]

        # Make sure prerelease and buildmetadata are at least an empty string
        if ($null -eq $Prerelease) {
            $Prerelease = ""
        }

        if ($null -eq $Buildmetadata) {
            $Buildmetadata = ""
        }

        # Check if we are a prerelease version
        $IsPrerelease = $false
        if (![string]::IsNullOrEmpty($Prerelease))
        {
            $IsPrerelease = $true
        }

        # Version is valid - Write to output stream
        Write-Verbose "Version is valid"
        [PSCustomObject]@{
            Raw = $Source
            Tag = $tag
            Major = $major
            Minor = $minor
            Patch = $patch
            Prerelease = $Prerelease
            Buildmetadata = $Buildmetadata
            BuildVersion = ("{0}.{1}.{2}.{3}" -f $major, $minor, $patch, (Get-BuildNumber))
            AssemblyVersion = "${major}.0.0.0"
            PlainVersion = ("{0}.{1}.{2}" -f $major, $minor, $patch)
            IsPrerelease = $IsPrerelease
        }

        $MatchFound = $true
    }

    end
    {
        if ($Required -and !$MatchFound)
        {
            # throw error as we didn't find a valid version source
            Write-Error "Could not find a valid version source"
        }
    }
}
