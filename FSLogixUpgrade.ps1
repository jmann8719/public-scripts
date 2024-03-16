# Create Transcript Log File
$Timestamp = Get-Date -Format 'ddMMyy_HHmm'
Start-Transcript -Path "$env:WINDIR\Temp\FSLogixUpgrade-$Timestamp.log" -Append

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

# Stop Transcript and Output Log File
Stop-Transcript
