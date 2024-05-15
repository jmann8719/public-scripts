# Create Transcript Log File
$Timestamp = Get-Date -Format 'ddMMyy_HHmm'
Start-Transcript -Path "$env:WINDIR\Temp\FSLogixUpgrade-$Timestamp.log" -Append

<# FSLogix Upgrade Process #>

# Retrieve FSLogix Installed Version
$InstalledVersion = Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall' | Get-ItemProperty | Where-Object { $_.DisplayName -match 'Microsoft FSLogix Apps' } | Select-Object -ExpandProperty 'DisplayVersion' | Get-Unique

# FSLogix Package Variables
$FSLogixInstaller = [System.Net.HttpWebRequest]::Create('https://aka.ms/fslogix_download').GetResponse().ResponseUri.AbsoluteUri
$FilenameExpression = '/([^/]+)\.zip$'
$VersionExpression = '(\d+(\.\d+)+)\.(\d+)'
$LatestFilename = [regex]::Match($FSLogixInstaller, $FilenameExpression).Groups[1].Value
$LatestVersion = [regex]::Match($LatestFilename, $VersionExpression).Groups[0].Value

# FSLogix Download and Upgrade
Write-Output "Installed version of FSLogix is $InstalledVersion and newest is $LatestVersion."
if ($InstalledVersion -ne $LatestVersion) {
    Write-Output "Installed version is not the latest. Downloading and Installing the most recent version..."
    $DownloadDestination = "$($env:WINDIR)\Temp"
    try {
        $InstallerExists = Test-Path -Path "$DownloadDestination\$($LatestFilename).zip"
        if ($InstallerExists) {
            Write-Output "Installer has already been downloaded, expanding the Archive..."
            Expand-Archive -LiteralPath "$DownloadDestination\$($LatestFilename).zip" -DestinationPath "$DownloadDestination\$($LatestFilename)"
        }
        else {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest $FSLogixInstaller -OutFile "$DownloadDestination\$($LatestFilename).zip"
            Expand-Archive -LiteralPath "$DownloadDestination\$($LatestFilename).zip" -DestinationPath "$DownloadDestination\$($LatestFilename)"
        }
        Write-Output "Checking Installer Package..."
        $FSLogixInstallerPath = "$DownloadDestination\$($LatestFilename)\x64\Release\FSLogixAppsSetup.exe"
        $FSLogixInstallerExists = Test-Path $FSLogixInstallerPath
        if ($FSLogixInstallerExists) {
            Write-Output "$FSLogixInstallerPath exists. Starting Install..."
            try {
                Start-Process -FilePath $FSLogixInstallerPath -ArgumentList "/quiet /norestart" -Wait
                Write-Output "Update Completed. Checking the current version in the Registry..."
                $UpdatedVersion = Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall' | Get-ItemProperty | Where-Object { $_.DisplayName -match 'Microsoft FSLogix Apps' } | Select-Object -ExpandProperty 'DisplayVersion' | Get-Unique
                Write-Output "Version after install is $UpdatedVersion."
            }
            catch {
                throw "FSLogix Failed to Install $_"
            }
        }
        else {
            throw "Installer doesn't exist, and FSLogix failed to upgrade. Exiting..."
        }
    }
    catch {
        Write-Warning "An error occurred either downloading FSLogix, or extracting the archive. Exiting..."
        throw $_
    }
}
else {
    Write-Output "Installed version is the latest release of FSLogix. Exiting..."
}

<# Implement FSLogix Registry Keys #>

# Check Registry Functions
function Test-RegistryValue($Path, $Name) {
    $Key = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    $Key -and $null -ne $Key.GetValue($Name, $null)
}
function Get-RegistryValue($Path, $Name) {
    $Key = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    if ($Key) {
        $Key.GetValue($Name, $null)
    }
}

# FSLogix Profiles Registry Path
$Profiles = 'HKLM:\SOFTWARE\FSLogix\Profiles'

# FSLogix 'RoamIdentity' Function Lookup
$Key_RoamIdentity = Test-RegistryValue -Path $Profiles -Name 'RoamIdentity'
$Value_RoamIdentity = Get-RegistryValue -Path $Profiles -Name 'RoamIdentity'

# FSLogix 'RoamIdentity' Key and Value Validation
if ($Key_RoamIdentity -and $Value_RoamIdentity -eq 1) {
    Write-Output "[RoamIdentity] Registry Key and Value Confirmed."
}
else {
    Write-Output "[RoamIdentity] Registry Key Missing or Value Incorrect. Updating..."
    New-ItemProperty -Path $Profiles -Name 'RoamIdentity' -PropertyType 'DWORD' -Value '1' -Force
}

# FSLogix 'LockedRetryCount' Function Lookup
$Key_LockedRetryCount = Test-RegistryValue -Path $Profiles -Name 'LockedRetryCount'
$Value_LockedRetryCount = Get-RegistryValue -Path $Profiles -Name 'LockedRetryCount'

# FSLogix 'LockedRetryCount' Key and Value Validation
if ($Key_LockedRetryCount -and $Value_LockedRetryCount -eq 3) {
    Write-Output "[LockedRetryCount] Registry Key and Value Confirmed."
}
else {
    Write-Output "[LockedRetryCount] Registry Key Missing or Value Incorrect. Updating..."
    New-ItemProperty -Path $Profiles -Name 'LockedRetryCount' -PropertyType 'DWORD' -Value '3' -Force
}

# FSLogix 'LockedRetryInterval' Function Lookup
$Key_LockedRetryInterval = Test-RegistryValue -Path $Profiles -Name 'LockedRetryInterval'
$Value_LockedRetryInterval = Get-RegistryValue -Path $Profiles -Name 'LockedRetryInterval'

# FSLogix 'LockedRetryInterval' Key and Value Validation
if ($Key_LockedRetryInterval -and $Value_LockedRetryInterval -eq 15) {
    Write-Output "[LockedRetryInterval] Registry Key and Value Confirmed."
}
else {
    Write-Output "[LockedRetryInterval] Registry Key Missing or Value Incorrect. Updating..."
    New-ItemProperty -Path $Profiles -Name 'LockedRetryInterval' -PropertyType 'DWORD' -Value 15 -Force
}

# FSLogix Apps Registry Path
$Apps = 'HKLM:\SOFTWARE\FSLogix\Apps'

# FSLogix 'CleanupInvalidSessions' Function Lookup
$Key_CleanupInvalidSessions = Test-RegistryValue -Path $Apps -Name 'CleanupInvalidSessions'
$Value_CleanupInvalidSessions = Get-RegistryValue -Path $Apps -Name 'CleanupInvalidSessions'

# FSLogix 'CleanupInvalidSessions' Key and Value Validation
if ($Key_CleanupInvalidSessions -and $Value_CleanupInvalidSessions -eq 1) {
    Write-Output "[CleanupInvalidSessions] Registry Key and Value Confirmed."
}
else {
    Write-Output "[CleanupInvalidSessions] Registry Key Missing or Value Incorrect. Updating..."
    New-ItemProperty -Path $Apps -Name 'CleanupInvalidSessions' -PropertyType 'DWORD' -Value '1' -Force
}

<# Implement Antivirus Exclusions #>

# Retrieve FSLogix Profile Location
$VHDShare = Get-ItemPropertyValue -LiteralPath HKLM:\SOFTWARE\FSLogix\Profiles -Name "VHDLocations"

# List of Paths/Processes/Extensions for Removal
$OldFileList = `
    "C:\Program Files\FSLogix\Apps\frxdrv.sys", `
    "C:\Program Files\FSLogix\Apps\frxdrvvt.sys", `
    "C:\Program Files\FSLogix\Apps\frxccd.sys", `
    "%TEMP%\*.VHD", `
    "%TEMP%\*.VHDX", `
    "%Windir%\TEMP\*.VHD", `
    "%Windir%\TEMP\*.VHDX", `
    "$($VHDShare)\*.VHD", `
    "$($VHDShare)\*.VHDX"

$OldProcessList = `
    "C:\Program Files\FSLogix\Apps\frxccd.exe", `
    "C:\Program Files\FSLogix\Apps\frxccds.exe", `
    "C:\Program Files\FSLogix\Apps\frxsvc.exe", `
    "%ProgramFiles%\FSLogix\Apps\frxccd.exe", `
    "%ProgramFiles%\FSLogix\Apps\frxccds.exe", `
    "%ProgramFiles%\FSLogix\Apps\frxsvc.exe", `
    "frxccd.exe", `
    "frxccds.exe", `
    "frxsvc.exe"

$OldExtensionList = `
    "%TEMP%\*.VHD", `
    "%TEMP%\*.VHDX", `
    "%Windir%\TEMP\*.VHD", `
    "%Windir%\TEMP\*.VHDX", `
    "$($VHDShare)\*.VHD", `
    "$($VHDShare)\*.VHDX"

# Loop File Lists Removing Defender Exclusions
Foreach ($OldItem in $OldFileList) {
    Remove-MpPreference -ExclusionPath $OldItem
}
Foreach ($OldItem in $OldProcessList) {
    Remove-MpPreference -ExclusionProcess $OldItem
}
Foreach ($OldItem in $OldExtensionList) {
    Remove-MpPreference -ExclusionExtension $OldItem
}

# List of Paths for Addition
$NewFileList = `
    "%TEMP%\*\*.VHD", `
    "%TEMP%\*\*.VHDX", `
    "%Windir%\TEMP\*\*.VHD", `
    "%Windir%\TEMP\*\*.VHDX", `
    "$($VHDShare)\*\*.VHD", `
    "$($VHDShare)\*\*.VHD.lock", `
    "$($VHDShare)\*\*.VHD.meta", `
    "$($VHDShare)\*\*.VHD.metadata", `
    "$($VHDShare)\*\*.VHDX", `
    "$($VHDShare)\*\*.VHDX.lock", `
    "$($VHDShare)\*\*.VHDX.meta", `
    "$($VHDShare)\*\*.VHDX.metadata"

# Loop File Paths Adding Defender Exclusions
Foreach ($NewItem in $NewFileList) {
    Add-MpPreference -ExclusionPath $NewItem
}

# Stop Transcript and Output Log File
Stop-Transcript
