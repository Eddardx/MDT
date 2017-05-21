<#
    .SYNOPSIS
        Get the latest Cumulative update for Windows

    .DESCRIPTION
        This script will return the list of Cumulative updates for Windows 10 and Windows Server 2016 from the Microsoft Update Catalog.

    .NOTES
        Name: Get-LatestUpdates.ps1
        Author: Aaron Parker
        Twitter: @stealthpuppy

        Original script:
        Copyright Keith Garner, All rights reserved.
        Forked from: https://gist.github.com/keithga/1ad0abd1f7ba6e2f8aff63d94ab03048

    .LINK
        https://support.microsoft.com/en-us/help/4000823

    .EXAMPLE
        Get the latest Cumulative Update for Windows 10 x64

        .\Get-LatestUpdate.ps1 

    .PARAMETER SearchString
        Specify a specific search string to change the target update behaviour. The default will only download Cumulative updates for x64.

    .EXAMPLE
        Get the latest Cumulative Update for Windows 10 x86

        .\Get-LatestUpdate.ps1 -SearchString 'Cumulative.*x86'

    .EXAMPLE
        Get the latest Cumulative Update for Windows Server 2016

        .\Get-LatestUpdate.ps1 -SearchString 'Cumulative.*Server.*x64' -Build 14393

    .PARAMETER Download
        Download the enumerated updates.

    .EXAMPLE
        Enumerate the latest Windows 10 Cumulative Update for build 14393 and download it.

        .\Get-LatestUpdate.ps1 -Download -Build 14393

    .PARAMETER Path
        Specify the path to download the updates, otherwise use the local folder.

    .EXAMPLE
        Enumerate the latest Windows 10 Cumulative Update and download to C:\Updates.

        .\Get-LatestUpdate.ps1 -Download -Path C:\Updates
#>
[CmdletBinding(SupportsShouldProcess = $True, ConfirmImpact = 'Low', DefaultParameterSetName='Base')]
Param(
    [Parameter(ParameterSetName='Base', Mandatory=$False, HelpMessage="JSON source for the update KB articles.")]
    [string]$StartKB = 'https://support.microsoft.com/api/content/asset/4000816',

    [Parameter(ParameterSetName='Base', Mandatory=$False, HelpMessage="Windows build number.")]
    [ValidateSet('15063','14393','10586','10240')]
    [string]$Build = '15063',

    [Parameter(ParameterSetName='Base', Mandatory=$False, HelpMessage="Search query string.")]
    [string]$SearchString = 'Cumulative.*x64',

    [Parameter(ParameterSetName='Base', Mandatory=$False, HelpMessage="Download the discovered updates.")]
    [switch]$Download,

    [Parameter(ParameterSetName='Base', Mandatory=$False, HelpMessage="Specify a target path to download the update(s) to.")]
    [ValidateScript({ If (Test-Path $_ -PathType 'Container') { $True } Else { Throw "Cannot find path $_" } })]
    [string]$Path = ".\",
)

#region Support Routine
Function Select-LatestUpdate {
    [CmdletBinding(SupportsShouldProcess=$True)]
    Param(
        [parameter(Mandatory=$True, ValueFromPipeline=$True)]
        $Updates
    )
    Begin { 
        $maxObject = $Null
        $maxValue = [version]::new("0.0")
    }
    Process {
        ForEach ( $Update in $Updates ) {
            Select-String -InputObject $Update -AllMatches -Pattern "(\d+\.)?(\d+\.)?(\d+\.)?(\*|\d+)" |
            ForEach-Object { $_.matches.value } |
            ForEach-Object { $_ -as [version] } |
            ForEach-Object { 
                If ( $_ -gt $MaxValue ) { $MaxObject = $Update; $MaxValue = $_ }
            }
        }
    }
    End { 
        $MaxObject | Write-Output 
    }
}
#endregion

#region Find the KB Article Number
Write-Verbose "Downloading $StartKB to retrieve the list of updates."
$kbID = (Invoke-WebRequest -Uri $StartKB).Content |
    ConvertFrom-Json |
    Select-Object -ExpandProperty Links |
    Where-Object level -eq 2 |
    Where-Object text -match $Build |
    Select-LatestUpdate |
    Select-Object -First 1
#endregion

#region get the download link from Windows Update
Write-Verbose "Found kbID: http://www.catalog.update.microsoft.com/Search.aspx?q=KB$($kbID.articleID)"
$kbObj = Invoke-WebRequest -Uri "http://www.catalog.update.microsoft.com/Search.aspx?q=KB$($kbID.articleID)"

$Available_kbIDs = $kbObj.InputFields | 
    Where-Object { $_.Type -eq 'Button' -and $_.Value -eq 'Download' } | 
    Select-Object -ExpandProperty ID

$Available_kbIDs | Out-String | Write-Verbose

$kbIDs = $kbObj.Links | 
    Where-Object ID -match '_link' |
    Where-Object innerText -match $SearchString |
    ForEach-Object { $_.Id.Replace('_link','') } |
    Where-Object { $_ -in $Available_kbIDs }

If ( $kbIDs -eq $Null ) {
    $kbIDs = $kbObj.Links | 
        Where-Object ID -match '_link' |
        Where-Object outerHTML -match $SearchString |
        ForEach-Object { $_.Id.Replace('_link','') } |
        Where-Object { $_ -in $Available_kbIDs }
}

ForEach ( $kbID in $kbIDs )
{
    Write-Verbose "`t`tDownload $kbID"
    $Post = @{ size = 0; updateID = $kbID; uidInfo = $kbID } | ConvertTo-Json -Compress
    $PostBody = @{ updateIDs = "[$Post]" } 
    $Urls = Invoke-WebRequest -Uri 'http://www.catalog.update.microsoft.com/DownloadDialog.aspx' -Method Post -Body $postBody |
        Select-Object -ExpandProperty Content |
        Select-String -AllMatches -Pattern "(http[s]?\://download\.windowsupdate\.com\/[^\'\""]*)" | 
        ForEach-Object { $_.matches.value }
}
#endregion

# Download the updates if -Download is specified
If ( $Download ) {
    ForEach ( $Url in $Urls ) {
        If ($pscmdlet.ShouldProcess($Url, "Download")) {
            $target = "$Path\$Url.Substring($Url.LastIndexOf("/") + 1)"
            Invoke-WebRequest -Uri $Url -OutFile $target
        }
    }
}

# Write the URLs list to the pipeline
Write-Output $Urls