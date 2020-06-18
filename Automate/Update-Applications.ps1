<# 
    .SYNOPSIS
        Update applications in an MDT share
#>
[CmdletBinding()]
Param (
    [System.String] $DeploymentShare = "E:\Deployment\Insentra\Automata"
)

# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"
$AppParentPath = Join-Path -Path $DeploymentShare -ChildPath "Applications"

# OneDrive
$AppChildPath = Join-Path -Path $AppParentPath -ChildPath "MicrosoftOneDrive"
$AppUpdate = Get-MicrosoftOneDrive | Where-Object { $_.Ring -eq "Production" } | `
    Sort-Object -Property Version -Descending | Select-Object -First 1
$OutFile = Join-Path -Path $AppChildPath -ChildPath $(Split-Path -Path $AppUpdate.URI -Leaf)
Invoke-WebRequest -Uri $AppUpdate.URI -OutFile $OutFile -UseBasicParsing
Unblock-File -Path $OutFile

# FSLogix
$AppChildPath = Join-Path -Path $AppParentPath -ChildPath "MicrosoftFSLogixApps"
$AppUpdate = Get-MicrosoftFSLogixApps
$OutFile = Join-Path -Path $AppChildPath -ChildPath $(Split-Path -Path $AppUpdate.URI -Leaf)
Invoke-WebRequest -Uri $AppUpdate.URI -OutFile $OutFile -UseBasicParsing
Expand-Archive -Path $OutFile -DestinationPath $(Join-Path -Path $AppChildPath -ChildPath "FSLogixApps")
Remove-Item -Path $OutFile -Force
Copy-Item -Path $(Join-Path -Path $(Join-Path -Path $AppChildPath -ChildPath "FSLogixApps") -ChildPath "x64\Release\*.exe") -Destination $AppChildPath -Force
Remove-Item -Path $(Join-Path -Path $AppChildPath -ChildPath "FSLogixApps") -Recurse -Force
Get-ChildItem -Path $AppChildPath | Unblock-File

# VMware Tools
$AppChildPath = Join-Path -Path $AppParentPath -ChildPath "VMwareTools"
$AppUpdate = Get-VMwareTools | Where-Object { $_.Architecture -eq "x64" }
$OutFile = Join-Path -Path $AppChildPath -ChildPath $(Split-Path -Path $AppUpdate.URI -Leaf)
Invoke-WebRequest -Uri $AppUpdate.URI -OutFile $OutFile -UseBasicParsing
Unblock-File -Path $OutFile
Get-ChildItem -Path $AppChildPath -Exclude (Get-Item -Path $OutFile).Name | Remove-Item -Force

# XenTools
$AppChildPath = Join-Path -Path $AppParentPath -ChildPath "XenTools"
$AppUpdate = Get-CitrixXenServerTools | Where-Object { $_.Architecture -eq "x64" }
$OutFile = Join-Path -Path $AppChildPath -ChildPath $(Split-Path -Path $AppUpdate.URI -Leaf)
Invoke-WebRequest -Uri $AppUpdate.URI -OutFile $OutFile -UseBasicParsing
Unblock-File -Path $OutFile

# Image customisations
$URL = "https://github.com/aaronparker/image-customise/archive/master.zip"
$AppChildPath = Join-Path -Path $AppParentPath -ChildPath "ImageCustomisations"
$OutFile = Join-Path -Path $AppChildPath -ChildPath $(Split-Path -Path $URL -Leaf)
Invoke-WebRequest -Uri $URL -OutFile $OutFile -UseBasicParsing
Expand-Archive -Path $OutFile -DestinationPath $AppChildPath
Remove-Item -Path $OutFile -Force
Copy-Item -Path $(Join-Path -Path $(Join-Path -Path $AppChildPath -ChildPath "image-customise-master") -ChildPath "*.ps1") -Destination $AppChildPath -Force
Copy-Item -Path $(Join-Path -Path $(Join-Path -Path $AppChildPath -ChildPath "image-customise-master") -ChildPath "*.xml") -Destination $AppChildPath -Force
Remove-Item -Path $(Join-Path -Path $AppChildPath -ChildPath "image-customise-master") -Recurse -Force

# VcRedists; Download the VcRedists
$Path = "C:\Temp\VcRedists"
If (!(Test-Path -Path $Path)) { New-Item -Path $Path -ItemType Directory }
Save-VcRedist -VcList (Get-VcList) -Path $Path

# Add to the deployment share
Update-VcMdtApplication -VcList (Get-VcList) -Path $Path -MdtPath $DeploymentShare -Silent
Update-VcMdtBundle -MdtPath $DeploymentShare

# Edge
$AppChildPath = Join-Path -Path $AppParentPath -ChildPath "MicrosoftEdge"
$AppUpdate = Get-MicrosoftEdge | Where-Object { $_.Architecture -eq "x64" -and $_.Channel -eq "Stable" }
$AppUpdate = $AppUpdate | Sort-Object -Property Version -Descending | Select-Object -First 1
$OutFile = Join-Path -Path $AppChildPath -ChildPath $(Split-Path -Path $AppUpdate.URI -Leaf)
Invoke-WebRequest -Uri $AppUpdate.URI -OutFile $OutFile -UseBasicParsing
Unblock-File -Path $OutFile

# Teams
$AppChildPath = Join-Path -Path $AppParentPath -ChildPath "MicrosoftTeams"
$AppUpdate = Get-MicrosoftTeams | Where-Object { $_.Architecture -eq "x64" }
$OutFile = Join-Path -Path $AppChildPath -ChildPath $(Split-Path -Path $AppUpdate.URI -Leaf)
Invoke-WebRequest -Uri $AppUpdate.URI -OutFile $OutFile -UseBasicParsing
Unblock-File -Path $OutFile

# Office
$AppChildPath = Join-Path -Path $AppParentPath -ChildPath "Microsoft365AppsMonthlyEnterprise"
$AppUpdate = Get-MicrosoftOffice | Where-Object { $_.Channel -eq "Monthly" }
$OutFile = Join-Path -Path $AppChildPath -ChildPath $(Split-Path -Path $AppUpdate.URI -Leaf)
Invoke-WebRequest -Uri $AppUpdate.URI -OutFile $OutFile -UseBasicParsing
Unblock-File -Path $OutFile

# Update Office
Push-Location -Path $AppChildPath
$params = @{
    FilePath     = (Join-Path -Path $AppChildPath -ChildPath "setup.exe")
    ArgumentList = "/download $(Join-Path -Path $AppChildPath -ChildPath "configuration.xml")"
    Wait         = $True
}
Start-Process @params
