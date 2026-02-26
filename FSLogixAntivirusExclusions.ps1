<#
.SYNOPSIS
    This script creates the required Windows Defender Antivirus Exclusions for FSLogix running on Azure Virtual Desktop Session Hosts.

.DESCRIPTION
    This script sets up Windows Defender Antivirus exclusions as suggested by Microsoft for FSLogix.
    The exclusions cover FSLogix executables, drivers and directories.
    Use this only on Azure Virtual Desktop Session Hosts that run FSLogix for User Profile Containers.

.EXAMPLE
    An example of how to run the script:
    PS C:\> .\FSLogixAntivirusExclusions.ps1

.NOTES
    Author: Jonathan Mann
    Date: 01st March 2026
    Version: 1.0

.LINK
    https://learn.microsoft.com/en-us/fslogix/overview-prerequisites
#>

# FSLogix Cloud Cache Exclusions
# Update to '$True' if using Cloud Cache
$CloudCache = $False

# FSLogix Storage Account and File Share Naming
# Specify names of the Azure Storage Account and File Share for FSLogix User Containers
$StorageAcct = "<STORAGEACCOUNT>"
$ShareName = "<FILESHARE>"

# FSLogix Process Exclusions
$Processes = `
    "frxsvc.exe", `
    "frxccds.exe"

# Loop and Implement FSLogix Process Exclusions
foreach ($Process in $Processes) {
    Add-MpPreference -ExclusionProcess $Process
}

# FSLogix File Path Exclusions
$Paths = `
    "%PROGRAMFILES%\FSLogix\Apps\frxdrv.sys", `
    "%PROGRAMFILES%\FSLogix\Apps\frxdrvvt.sys", `
    "%PROGRAMFILES%\FSLogix\Apps\frxccd.sys", `
    "%SYSTEMDRIVE%\Users\*\AppData\Local\FSLogix\", `
    "%SYSTEMDRIVE%\Users\*\AppData\Local\Temp\*\*.VHD", `
    "%SYSTEMDRIVE%\Users\*\AppData\Local\Temp\*\*.VHDX", `
    "%WINDIR%\TEMP\*\*.VHD", `
    "%WINDIR%\TEMP\*\*.VHDX", `
    "\\$StorageAcct.file.core.windows.net\$ShareName\*\*.VHD", `
    "\\$StorageAcct.file.core.windows.net\$ShareName\*\*.VHD.lock", `
    "\\$StorageAcct.file.core.windows.net\$ShareName\*\*.VHD.meta", `
    "\\$StorageAcct.file.core.windows.net\$ShareName\*\*.VHD.metadata", `
    "\\$StorageAcct.file.core.windows.net\$ShareName\*\*.VHDX", `
    "\\$StorageAcct.file.core.windows.net\$ShareName\*\*.VHDX.lock", `
    "\\$StorageAcct.file.core.windows.net\$ShareName\*\*.VHDX.meta", `
    "\\$StorageAcct.file.core.windows.net\$ShareName\*\*.VHDX.metadata"

# Loop and Implement FSLogix File Path Exclusions
foreach ($Path in $Paths) {
    Add-MpPreference -ExclusionPath $Path
}

# If utilised, FSLogix Cloud Cache Exclusions.
if ($CloudCache) {
    Add-MpPreference -ExclusionPath "%PROGRAMDATA%\FSLogix\Cache\*"
    Add-MpPreference -ExclusionPath "%PROGRAMDATA%\FSLogix\Proxy\*"
}
