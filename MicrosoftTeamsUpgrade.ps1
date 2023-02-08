# Microsoft Teams and Web RTC Component Upgrade Script
# Author: Nerdio Scripted Actions (GitHub)

# PowerShell Logging
$SaveVerbosePreference = $VerbosePreference
$VerbosePreference = 'Continue'
$VMTime = Get-Date
$LogTime = $VMTime.ToUniversalTime()
mkdir "C:\Windows\Temp\NMWLogs\ScriptedActions\MSTeams" -Force
Start-Transcript -Path "C:\Windows\Temp\NMWLogs\ScriptedActions\MSTeams\PS_Log.txt" -Append
Write-Host "################# New Script Run #################"
Write-Host "Current Time (UTC-0): $LogTime"

# Check for Public Desktop Shortcut
$Shortcut = Test-Path -Path "C:\Users\Public\Desktop\Microsoft Teams.lnk"
if ($Shortcut -eq $true) {
    Write-Host "Public Desktop Shortcut for Microsoft Teams exists, and will be recreated."
}
else {
    Write-Host "Public Desktop Shortcut for Microsoft Teams doesn't exist."
}

# Set Registry Values for Teams to use VDI Optimization
Write-Host "INFO: Adjusting Registry to Set Teams to AVD Environment Mode" -ForegroundColor Gray
reg add HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Teams /v "IsWVDEnvironment" /t REG_DWORD /d 1 /f

# Uninstall Previous Versions of Microsoft Teams and/or Web RTC Component
# Per-User Teams Uninstallation Logic
$TeamsPath = [System.IO.Path]::Combine($env:LOCALAPPDATA, 'Microsoft', 'Teams')
$TeamsUpdateExePath = [System.IO.Path]::Combine($env:LOCALAPPDATA, 'Microsoft', 'Teams', 'Update.exe')
try {
    if ([System.IO.File]::Exists($TeamsUpdateExePath)) {
        Write-Host "INFO: Uninstalling Teams Process (Per-User Installation)"
        # Uninstall App
        $proc = Start-Process $TeamsUpdateExePath "-uninstall -s" -PassThru
        $proc.WaitForExit()
    }
    else {
        Write-Host "INFO: No Per-User Teams Install Found."
    }
    Write-Host "INFO: Deleting Teams Directories (Per-User Installation)."
    Remove-Item -Path $TeamsPath -Recurse -ErrorAction SilentlyContinue
}
catch {
    Write-Output "Uninstall Failed with Exception $_.Exception.Message"
}

# Per-User Teams Uninstallation Logic
$GetTeams = Get-WMIObject Win32_Product | Where-Object IdentifyingNumber -match "{731F6BAA-A986-45A4-8936-7C3AAAAA760B}"
if ($null -ne $GetTeams) {
    Start-Process C:\Windows\System32\msiexec.exe -ArgumentList '/x "{731F6BAA-A986-45A4-8936-7C3AAAAA760B}" /qn /norestart' -Wait
    Write-Host "INFO: Teams Per-Machine Install Identified, Uninstalling Teams."
}

# Web RTC Component Uninstallation Logic
$GetWebRTC = Get-WMIObject Win32_Product | Where-Object IdentifyingNumber -match "{FB41EDB3-4138-4240-AC09-B5A184E8F8E4}"
if ($null -ne $GetWebRTC) {
    Start-Process C:\Windows\System32\msiexec.exe -ArgumentList '/x "{FB41EDB3-4138-4240-AC09-B5A184E8F8E4}" /qn /norestart' -Wait
    Write-Host "INFO: Web RTC Component Install Identified, Uninstalling RTC Component."
}

# Create Directory for Installers
mkdir "C:\Windows\Temp\MSTeams_SA\Install" -Force

# Download MSI Installater for Microsoft Teams
$DLink = "https://teams.microsoft.com/downloads/desktopurl?env=production&plat=windows&arch=x64&managedInstaller=true&download=true"
Invoke-WebRequest -Uri $DLink -OutFile "C:\Windows\Temp\MSTeams_SA\Install\Teams_Windows_x64.msi" -UseBasicParsing

# Utilise for Machine-Wide Installation
Write-Host "INFO: Installing Microsoft Teams"
Start-Process C:\Windows\System32\msiexec.exe `
    -ArgumentList  '/i C:\Windows\Temp\MSTeams_SA\Install\Teams_Windows_x64.msi /l*v C:\Windows\Temp\NMWLogs\ScriptedActions\MSTeams\Teams_Install_Log.txt ALLUSER=1 ALLUSERS=1 /qn /norestart' -Wait

# Download MSI Installater for Web RTC Component
$dlink2 = "https://aka.ms/msrdcwebrtcsvc/msi"
Invoke-WebRequest -Uri $DLink2 -OutFile "C:\Windows\Temp\MSTeams_SA\Install\MsRdcWebRTCSvc_x64.msi" -UseBasicParsing

# Utilise for Machine-Wide Installation
Write-Host "INFO: Installing Web RTC Component"
Start-Process C:\Windows\System32\msiexec.exe `
    -ArgumentList '/i C:\Windows\Temp\MSTeams_SA\Install\MsRdcWebRTCSvc_x64.msi /l*v C:\Windows\Temp\NMWLogs\ScriptedActions\MSTeams\WebRTC_install_log.txt /qn /norestart' -Wait

# Installation Summary
Write-Host "INFO: Finished Running Installers. Check 'C:\Windows\Temp\MSTeams_SA' for Logs on the MSI installations."

# Create Public Desktop Shortcut
if ($Shortcut -eq $true) {
    Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Teams.lnk" -Destination "C:\Users\Public\Desktop"
}
else {
    Write-Host "Public Desktop Shortcut for Microsoft Teams didn't exist, will not create one."
}

# Script Completion
Write-Host "INFO: Script is now Finished. Please allow 5 minutes for Microsoft Teams to appear." -ForegroundColor Green

# End Logging
Stop-Transcript
$VerbosePreference = $SaveVerbosePreference
