# Specify Language Pack
$TargetLanguage = "EN-GB"

$VMTime = Get-Date
$LogTime = $VMTime.ToUniversalTime()

Start-Transcript -Path "$env:Temp\LanguagePack-$TargetLanguage-Install.log" -Append
Write-Host "Current Time: $LogTime"
Write-Host "The following Language Pack will be installed: $TargetLanguage"

# Disables Scheduled Tasks
Disable-ScheduledTask -TaskPath "\Microsoft\Windows\AppxDeploymentClient\" -TaskName "Pre-Staged App Cleanup" | Out-Null
Disable-ScheduledTask -TaskPath "\Microsoft\Windows\MUI\" -TaskName "LPRemove" | Out-Null
Disable-ScheduledTask -TaskPath "\Microsoft\Windows\LanguageComponentsInstaller" -TaskName "Uninstallation" | Out-Null
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Control Panel\International" /v "BlockCleanupOfUnusedPreinstalledLangPacks" /t REG_DWORD /d 1 /f | Out-Null

# Language Pack Installation
Write-Host "Installing Language Pack for: $TargetLanguage"
Install-Language $TargetLanguage
Write-Host "Installing Language Pack for: $TargetLanguage Completed."

# Adds Language Pack for Selection
$LanguageList = Get-WinUserLanguageList
$LanguageList.Add("$TargetLanguage")
Set-WinUserLanguageList $LanguageList -Force

$DefaultLanguage = Read-Host "Do you want to set $TargetLanguage as default? (Y/N)"

# Sets Language Pack as Default
if ($DefaultLanguage.ToLower() -eq "Y") {
    Write-Host "Setting Default Language to: $TargetLanguage"
    Set-SystemPreferredUILanguage $TargetLanguage
    Set-WinUILanguageOverride -Language $TargetLanguage
    Set-WinSystemLocale -SystemLocale $TargetLanguage
}
else {
    Write-Host "Default Language hasn't been configured."
}

Stop-Transcript
