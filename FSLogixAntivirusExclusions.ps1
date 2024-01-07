# Windows Defender Exclusions for FSLogix
$CloudCache = $false # Set True if using FSLogix Cloud Cache
$StorageAcct = "<STORAGEACCOUNT>" # Storage Account Name
$ShareName = "<FILESHARE>" # Storage Account's File Share Name

$FileList = `
    "%TEMP%\*\*.VHD", `
    "%TEMP%\*\*.VHDX", `
    "%Windir%\TEMP\*\*.VHD", `
    "%Windir%\TEMP\*\*.VHDX", `
    "\\$StorageAcct.file.core.windows.net\$ShareName\*\*.VHD", `
    "\\$StorageAcct.file.core.windows.net\$ShareName\*\*.VHD.lock", `
    "\\$StorageAcct.file.core.windows.net\$ShareName\*\*.VHD.meta", `
    "\\$StorageAcct.file.core.windows.net\$ShareName\*\*.VHD.metadata", `
    "\\$StorageAcct.file.core.windows.net\$ShareName\*\*.VHDX", `
    "\\$StorageAcct.file.core.windows.net\$ShareName\*\*.VHDX.lock", `
    "\\$StorageAcct.file.core.windows.net\$ShareName\*\*.VHDX.meta", `
    "\\$StorageAcct.file.core.windows.net\$ShareName\*\*.VHDX.metadata"

Foreach ($Item in $FileList) {
    Add-MpPreference -ExclusionPath $Item
}

If ($CloudCache) {
    Add-MpPreference -ExclusionPath "%ProgramData%\FSLogix\Cache\*"
    Add-MpPreference -ExclusionPath "%ProgramData%\FSLogix\Proxy\*"
}
