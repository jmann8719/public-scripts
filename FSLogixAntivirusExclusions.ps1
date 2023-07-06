# Windows Defender Exclusions for FSLogix
$CloudCache = $false # Set True if using FSLogix Cloud Cache
$StorageAcct = "<STORAGEACCOUNT>" # Storage Account Name
$ShareName = "<FILESHARE>" # Storage Account's File Share Name

$FileList = `
    "%ProgramFiles%\FSLogix\Apps\frxdrv.sys", `
    "%ProgramFiles%\FSLogix\Apps\frxdrvvt.sys", `
    "%ProgramFiles%\FSLogix\Apps\frxccd.sys", `
    "%TEMP%\*.VHD", `
    "%TEMP%\*.VHDX", `
    "%Windir%\TEMP\*.VHD", `
    "%Windir%\TEMP\*.VHDX", `
    "\\$StorageAcct.file.core.windows.net\$ShareName\*.VHD", `
    "\\$StorageAcct.file.core.windows.net\$ShareName\*.VHDX"

$ProcessList = `
    "%ProgramFiles%\FSLogix\Apps\frxccd.exe", `
    "%ProgramFiles%\FSLogix\Apps\frxccds.exe", `
    "%ProgramFiles%\FSLogix\Apps\frxsvc.exe"

Foreach ($Item in $FileList) {
    Add-MpPreference -ExclusionPath $Item
}
Foreach ($Item in $ProcessList) {
    Add-MpPreference -ExclusionProcess $Item
}

If ($CloudCache) {
    Add-MpPreference -ExclusionPath "%ProgramData%\FSLogix\Cache\*.VHD"
    Add-MpPreference -ExclusionPath "%ProgramData%\FSLogix\Cache\*.VHDX"
    Add-MpPreference -ExclusionPath "%ProgramData%\FSLogix\Proxy\*.VHD"
    Add-MpPreference -ExclusionPath "%ProgramData%\FSLogix\Proxy\*.VHDX"
}
