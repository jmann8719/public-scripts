# Create Transcript Log File
$PackageName = "MicrosoftTeams"
$LogPath = "$env:Temp\$PackageName-Install.log"

Start-Transcript -Path $LogPath -Append -Force

# Checks for User Sessions
$AllUsers = query user
$ActiveUsers = $AllUsers | Select-String -Pattern "Active"
$DisconnectedUsers = $AllUsers | Select-String -Pattern "Disc"

$AllowedUsernames = @("IRISAdmin", "AVDAdmin")

$LoggedInUsernames = $ActiveUsers | Where-Object { $AllowedUsernames }

if ($LoggedInUsernames.Count -eq 1 -and $DisconnectedUsers.Count -eq 0) {
    Write-Host "You are the only logged-in user, and there are no disconnected sessions. Continuing..."
}
else {
    Write-Host "There are other active or disconnected sessions, or unauthorised users logged in. Please sign out these users before continuing." -ForegroundColor Red
    return
}

# Check FSLogix Version Compatibility
$Req_FSLogix = '2.9.8716.30241'
$Ins_FSLogix = (Get-ItemProperty -Path 'HKLM:\Software\FSLogix\Apps' -Name InstallVersion).InstallVersion

if ($Ins_FSLogix -ge $Req_FSLogix) {
    Write-Host "FSLogix version $($Ins_FSLogix). This meets or exceeds the required version. Continuing..."
}
else {
    Write-Host "FSLogix version $($Ins_FSLogix) is below the required version of $($Req_FSLogix). Please upgrade FSLogix to the latest version, and then retry." -ForegroundColor Red
    return
}

# Uninstall Function for Microsoft Teams Classic
function Uninstall-TeamsClassic($TeamsPath) {
    try {
        $Process = Start-Process -FilePath "$TeamsPath\Update.exe" -ArgumentList "--uninstall /s" -PassThru -Wait -ErrorAction Stop
        if ($Process.ExitCode -ne 0) {
            Write-Error "Uninstallation Failed with Exit Code $($Process.ExitCode)."
        }
    }
    catch {
        Write-Error $_.Exception.Message
    }
}

# Uninstalls Microsoft Teams Classic Machine-wide Installer
Write-Host "Removing Teams Machine-wide Installer"
$MachineWide = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -eq "Teams Machine-Wide Installer" }

if ($MachineWide) {
    $MachineWide.Uninstall()
}
else {
    Write-Host "Teams Machine-Wide Installer Not Found"
}

# Uninstalls Microsoft Teams Classic from Per-User Installs
$AllUsers = Get-ChildItem -Path "$($env:SystemDrive)\Users"

foreach ($User in $AllUsers) {
    Write-Host "Processing User: $($User.Name)"
    $LocalAppData = "$($env:SystemDrive)\Users\$($User.Name)\AppData\Local\Microsoft\Teams"
    $ProgramData = "$($env:ProgramData)\$($User.Name)\Microsoft\Teams"
    if (Test-Path "$LocalAppData\Current\Teams.exe") {
        Write-Host "Uninstalling Teams for User $($User.Name)"
        Uninstall-TeamsClassic -TeamsPath $LocalAppData
    }
    elseif (Test-Path "$ProgramData\Current\Teams.exe") {
        Write-Host "Uninstalling Teams for User $($User.Name)"
        Uninstall-TeamsClassic -TeamsPath $ProgramData
    }
    else {
        Write-Host "Teams Installation Not Found For User $($User.Name)"
    }
}

# Folder and Shortcut Removal
Write-Host "Removing Teams Classic Installation Folder"
$TeamsFolderCleanup = "$($env:SystemDrive)\Users\*\AppData\Local\Microsoft\Teams"
Get-Item $TeamsFolderCleanup | Remove-Item -Force -Recurse

Write-Host "Removing Teams Classic Program Shortcut"
$TeamsIconCleanup = "$($env:SystemDrive)\Users\*\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Microsoft Teams*.lnk"
Get-Item $TeamsIconCleanup | Remove-Item -Force -Recurse

# Register as Azure Virtual Desktop Environment
Write-Host "Register as Azure Virtual Desktop Environment"
New-Item -Path "HKLM:\SOFTWARE\Microsoft" -Name "Teams" -Force -ErrorAction Ignore
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Teams" -Name "IsWVDEnvironment" -Value 1 -Force

# Allow Side-Loading Trusted Applications
Write-Host "Allow Side-Loading Trusted Applications"
New-Item -Path "HKLM:\Software\Policies\Microsoft\Windows" -Name "Appx" -Force -ErrorAction Ignore
New-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\Appx" -Name "AllowAllTrustedApps" -Value 1 -Force

# Downloading and Installing WebView2 Runtime
Write-Host "Downloading and Installing WebView2 Runtime"
Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/p/?LinkId=2124703" -OutFile "$($env:Temp)\WebView2.exe"
Start-Process -FilePath "$($env:Temp)\WebView2.exe" -Wait -ArgumentList "/silent /install" -ErrorAction SilentlyContinue

# Downloading and Installing Microsoft Teams
Write-Host "Downloading and Installing Microsoft Teams"
Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2243204" -OutFile "$($env:Temp)\TeamsBootstrapper.exe"
Start-Process -FilePath "$($env:Temp)\TeamsBootstrapper.exe" -Wait -ArgumentList "-p" -PassThru -ErrorAction SilentlyContinue

# Stop Transcript and Output Log File
Stop-Transcript
