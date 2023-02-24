<#
.SYNOPSIS
Script to install and configure Language Packs via Install-Language
.LINK
https://github.com/StefanDingemanse
#>

$LanguagePacks = "EN-GB"
$DefaultLanguage = "EN-GB"

$SaveVerbosePreference = $VerbosePreference
$VerbosePreference = 'Continue'
$VMTime = Get-Date
$LogTime = $VMTime.ToUniversalTime()

Start-Transcript -Path "C:\Windows\Temp\LanguagePackInstallation.log" -Append
Write-Host "################# New Script Run #################"
Write-Host "Current Time (UTC-0): $LogTime"
Write-Host "The following Language Packs will be installed"
Write-Host "$LanguagePacks"

Disable-ScheduledTask -TaskPath "\Microsoft\Windows\AppxDeploymentClient\" -TaskName "Pre-Staged App Cleanup" | Out-Null

foreach ($Language in $LanguagePacks) {
    Write-Host "Installing Language Pack for: $Language"
    Install-Language $Language
    Write-Host "Installing Language Pack for: $Language Completed."
}
if ($DefaultLanguage -eq $null) {
    Write-Host "Default Language isn't configured."
}
else {
    Write-Host "Setting Default Language to: $DefaultLanguage"
    Set-SystemPreferredUILanguage $DefaultLanguage
}

Stop-Transcript
$VerbosePreference = $SaveVerbosePreference
