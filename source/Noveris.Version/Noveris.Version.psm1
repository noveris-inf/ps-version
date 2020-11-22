<#
#>

################
# Global settings
$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

################
# Script variables
$script:MinDate = (New-Object DateTime -ArgumentList 1970, 1, 1)

<#
#>
Class VersionStore
{
    [int]$Major
    [int]$Minor
    [int]$Patch
    [int]$Build

    <#
    #>
    VersionStore()
    {
        $this.Major = 0
        $this.Minor = 0
        $this.Patch = 0
        $this.Build = 0

        $this | Add-Member -Name SemVer -MemberType ScriptProperty -Value {
            return ([string]::Format("{0}.{1}.{2}", $this.Major, $this.Minor, $this.Patch))
        }

        $this | Add-Member -Name FullVer -MemberType ScriptProperty -Value {
            return ([string]::Format("{0}.{1}.{2}.{3}", $this.Major, $this.Minor, $this.Patch, $this.Build))
        }
    }

    <#
    #>
    VersionStore([VersionStore] $version)
    {
        $this.Major = $version.Major
        $this.Minor = $version.Minor
        $this.Patch = $version.Patch
        $this.Build = $version.Build

        $this | Add-Member -Name SemVer -MemberType ScriptProperty -Value {
            return ([string]::Format("{0}.{1}.{2}", $this.Major, $this.Minor, $this.Patch))
        }

        $this | Add-Member -Name FullVer -MemberType ScriptProperty -Value {
            return ([string]::Format("{0}.{1}.{2}.{3}", $this.Major, $this.Minor, $this.Patch, $this.Build))
        }
    }

    <#
    #>
    [string] ToString()
    {
        return ([string]::Format("{0}.{1}.{2}", $this.Major, $this.Minor, $this.Patch))
    }
}

<#
#>
Function ConvertTo-VersionStore
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Version,

        [Parameter(Mandatory=$false)]
        [switch]$AddMissingBuildNumber = $false,

        [Parameter(Mandatory=$false)]
        [switch]$ForceBuildGeneration = $false,

        [Parameter(Mandatory=$false,ParameterSetName="AllMustMatch")]
        [switch]$AllMustMatch = $false,

        [Parameter(Mandatory=$false,ParameterSetName="MatchFirst")]
        [switch]$MatchFirst = $false,

        [Parameter(Mandatory=$false)]
        [switch]$MatchRequired = $false
    )

    begin
    {
        $matchNum = 0
        $stopProcessing = $false
    }

    process
    {
        if ($stopProcessing)
        {
            return
        }

        Write-Verbose "Processing version: $Version"
        $source = $Version

        # Ignore empty version sources (or fail, if strict)
        if ([string]::IsNullOrEmpty($source))
        {
            if ($AllMustMatch)
            {
                throw New-Object ArgumentException -ArgumentList "Version supplied (${source}) is not formatted correctly"
            }

            return
        }

        # Strip any refs/tags/ reference at the beginning of the version source
        $tagBranch = "refs/tags/"
        if ($source.StartsWith($tagBranch))
        {
            Write-Verbose "Version in refs/tags format"
            $source = $source.Substring($tagBranch.Length)
        }

        $versionStore = New-Object VersionStore
        
        # Check for three number version format (Major.Minor.Patch)
        if ($source -match "^[v]*([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$")
        {
            Write-Verbose "Version matches Major.Minor.Patch.Build format"
            $major = [Convert]::ToInt64($Matches[1])
            $minor = [Convert]::ToInt64($Matches[2])
            $patch = [Convert]::ToInt64($Matches[3])
            $build = [Convert]::ToInt64($Matches[4])

            $versionStore.Major = $major
            $versionStore.Minor = $minor
            $versionStore.Patch = $patch
            $versionStore.Build = $build

            if ($ForceBuildGeneration)
            {
                Write-Verbose "Forcing regeneration of build number"
                $versionStore.Build = [Int64]([DateTime]::Now - $script:MinDate).TotalDays
            }

            $matchNum++
            $versionStore

            if ($MatchFirst)
            {
                Write-Verbose "MatchFirst specified and match found"
                $stopProcessing = $true
            }
        }
        # Check for four number version format (Major.Minor.Patch.Build)
        elseif ($source -match "^[v]*([0-9]+)\.([0-9]+)\.([0-9]+)$")
        {
            Write-Verbose "Version matches Major.Minor.Patch format"
            $major = [Convert]::ToInt64($Matches[1])
            $minor = [Convert]::ToInt64($Matches[2])
            $patch = [Convert]::ToInt64($Matches[3])

            $versionStore.Major = $major
            $versionStore.Minor = $minor
            $versionStore.Patch = $patch

            $versionStore.Build = 0
            if ($ForceBuildGeneration)
            {
                Write-Verbose "Forcing regeneration of build number"
                $versionStore.Build = [Int64]([DateTime]::Now - $script:MinDate).TotalDays
            }
            elseif ($AddMissingBuildNumber)
            {
                Write-Verbose "Adding missing build number"
                $versionStore.Build = [Int64]([DateTime]::Now - $script:MinDate).TotalDays
            }

            $matchNum++
            $versionStore

            if ($MatchFirst)
            {
                Write-Verbose "MatchFirst specified and match found"
                $stopProcessing = $true
            }
        }
        else
        {
            # Couldn't identify a usable version format
            if ($AllMustMatch)
            {
                throw New-Object ArgumentException -ArgumentList "Version supplied (${source}) is not formatted correctly"
            }
        }
    }

    end
    {
        if ($MatchRequired -and $matchNum -lt 1)
        {
            throw New-Object Exception -ArgumentList "MatchRequired specified and no match found"
        }
    }
}

<#
#>
Function Update-VersionStore
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline)]
        [VersionStore]$Version,

        [Parameter(Mandatory=$false)]
        [switch]$IncrementMajor = $false,

        [Parameter(Mandatory=$false)]
        [switch]$IncrementMinor = $false,

        [Parameter(Mandatory=$false)]
        [switch]$IncrementPatch,

        [Parameter(Mandatory=$false)]
        [switch]$AddMissingBuildNumber = $false,

        [Parameter(Mandatory=$false)]
        [switch]$ForceBuildGeneration = $false
    )

    process
    {
        if ($Version -eq $null)
        {
            return
        }

        if ($IncrementPatch)
        {
            $Version.Patch++
        }

        if ($IncrementMinor)
        {
            $Version.Minor++
            $version.Patch = 0
        }

        if ($IncrementMajor)
        {
            $Version.Major++
            $Version.Minor = 0
            $Version.Patch = 0
        }

        if (($AddMissingBuildNumber -and $Version.Build -eq 0) -or $ForceBuildGeneration)
        {
            $version.Build = [Int64]([DateTime]::Now - $script:MinDate).TotalDays
        }

        $Version
    }
}
