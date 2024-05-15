# Check Microsoft Teams Existence
Write-Host "Checking existence of Microsoft Teams..." -ForegroundColor Yellow
$TeamsInstalled = Get-WmiObject -Class Win32_Product | Sort-Object Name | Select-Object Name, Vendor | Where-Object { ($_.Name -like "*Teams*") -and ($_.Vendor -like "*Microsoft*") }
if ($TeamsInstalled) {
    Write-Host "Microsoft Teams is installed, upgrade will now proceed." -ForegroundColor Green

    # Create Transcript Log File
    $Timestamp = Get-Date -Format 'ddMMyy_HHmm'
    $LogPath = "$env:WINDIR\Temp\MicrosoftTeamsInstall-$Timestamp.log"
    Start-Transcript -Path $LogPath -Append -Force

    # Check FSLogix Version Compatibility
    $Req_FSLogix = "2.9.8716.30241"
    $Ins_FSLogix = (Get-ItemProperty -Path 'HKLM:\Software\FSLogix\Apps' -Name InstallVersion).InstallVersion

    if ($Ins_FSLogix -ge $Req_FSLogix) {
        Write-Output "FSLogix version $($Ins_FSLogix). This meets or exceeds the required version. Continuing..."
    }
    else {
        Write-Output "FSLogix version $($Ins_FSLogix) is below the required version of $($Req_FSLogix). Please upgrade FSLogix to the latest version, and then retry." -ForegroundColor Red
        return
    }

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
    Write-Output "Removing Teams Machine-wide Installer"
    $MachineWide = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -eq "Teams Machine-Wide Installer" }

    if ($MachineWide) {
        $MachineWide.Uninstall()
    }
    else {
        Write-Output "Teams Machine-Wide Installer Not Found"
    }

    # Uninstalls Microsoft Teams Classic from Per-User Installs
    $AllUsers = Get-ChildItem -Path "$($env:SystemDrive)\Users"

    foreach ($User in $AllUsers) {
        Write-Output "Processing User: $($User.Name)"
        $LocalAppData = "$($env:SystemDrive)\Users\$($User.Name)\AppData\Local\Microsoft\Teams"
        $ProgramData = "$($env:ProgramData)\$($User.Name)\Microsoft\Teams"
        if (Test-Path "$LocalAppData\Current\Teams.exe") {
            Write-Output "Uninstalling Teams for User $($User.Name)"
            Uninstall-TeamsClassic -TeamsPath $LocalAppData
        }
        elseif (Test-Path "$ProgramData\Current\Teams.exe") {
            Write-Output "Uninstalling Teams for User $($User.Name)"
            Uninstall-TeamsClassic -TeamsPath $ProgramData
        }
        else {
            Write-Output "Teams Installation Not Found For User $($User.Name)"
        }
    }

    # Folder and Shortcut Removal
    Write-Output "Removing Teams Classic Installation Folder"
    $TeamsFolderCleanup = "$($env:SystemDrive)\Users\*\AppData\Local\Microsoft\Teams"
    Get-Item $TeamsFolderCleanup | Remove-Item -Force -Recurse

    Write-Output "Removing Teams Classic Program Shortcut"
    $TeamsIconCleanup = "$($env:SystemDrive)\Users\*\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Microsoft Teams*.lnk"
    Get-Item $TeamsIconCleanup | Remove-Item -Force -Recurse

    # Register as Azure Virtual Desktop Environment
    Write-Output "Register as Azure Virtual Desktop Environment"
    $Key_WVDEnvironment = Test-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Teams' -Name 'IsWVDEnvironment'
    $Value_WVDEnvironment = Get-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Teams' -Name 'IsWVDEnvironment'
    if ($Key_WVDEnvironment -and $Value_WVDEnvironment -eq 1) {
        Write-Output "[ISWVDENVIRONMENT] Registry Key and Value Confirmed."
    }
    else {
        Write-Output "[ISWVDENVIRONMENT] Registry Key Missing or Value Incorrect. Updating..."
        New-Item -Path "HKLM:\SOFTWARE\Microsoft" -Name "Teams" -Force -ErrorAction Ignore
        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Teams" -Name "IsWVDEnvironment" -Value 1 -Force
    }

    # Allow Side-Loading Trusted Applications
    Write-Output "Allow Side-Loading Trusted Applications"
    $Key_AllowAllTrustedApps = Test-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\Appx' -Name 'AllowAllTrustedApps'
    $Value_AllowAllTrustedApps = Get-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\Appx' -Name 'AllowAllTrustedApps'
    if ($Key_AllowAllTrustedApps -and $Value_AllowAllTrustedApps -eq 1) {
        Write-Output "[AllowAllTrustedApps] Registry Key and Value Confirmed."
    }
    else {
        Write-Output "[AllowAllTrustedApps] Registry Key Missing or Value Incorrect. Updating..."
        New-Item -Path "HKLM:\Software\Policies\Microsoft\Windows" -Name "Appx" -Force -ErrorAction Ignore
        New-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\Appx" -Name "AllowAllTrustedApps" -Value 1 -Force    
    }

    $ProgressPreference = 'SilentlyContinue'

    # Downloading and Installing Remote Desktop WebRTC Redirector Service
    Write-Output "Downloading and Installing Remote Desktop WebRTC Redirector Service"
    Invoke-WebRequest -Uri "https://aka.ms/msrdcwebrtcsvc/msi" -OutFile "$($env:WINDIR)\Temp\MSRDCWEBRTCSVC_x64.msi"
    Start-Process -FilePath "msiexec.exe" -Wait -ArgumentList "/i", "`"$env:WINDIR\Temp\MSRDCWEBRTCSVC_x64.msi`"", "/l*v `"$env:WINDIR\Temp\MSRDCWEBRTCSVC_Install.log`"", "/qn /norestart"

    # Downloading and Installing WebView2 Runtime
    Write-Output "Downloading and Installing WebView2 Runtime"
    Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/p/?LinkId=2124703" -OutFile "$($env:WINDIR)\Temp\MicrosoftEdgeWebview2Setup.exe"
    Start-Process -FilePath "$($env:WINDIR)\Temp\MicrosoftEdgeWebview2Setup.exe" -Wait -ArgumentList "/silent /install" -ErrorAction SilentlyContinue

    # Downloading and Installing Microsoft Teams
    Write-Output "Downloading and Installing Microsoft Teams"
    Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2243204" -OutFile "$($env:WINDIR)\Temp\TeamsBootstrapper.exe"
    Start-Process -FilePath "$($env:WINDIR)\Temp\TeamsBootstrapper.exe" -Wait -ArgumentList "-p" -PassThru -ErrorAction SilentlyContinue

    # Microsoft Teams Meeting Add-in for Outlook
    $PackagePath = Get-AppxPackage -Name MSTeams
    Start-Process -FilePath "msiexec.exe" -Wait -ArgumentList "/i", "`"$(($PackagePath).InstallLocation)\MicrosoftTeamsMeetingAddinInstaller.msi`"", "ALLUSERS=1 TARGETDIR=""C:\Program Files (x86)\Microsoft\TeamsMeetingAddin"" /qn /norestart"

    # Registry Keys for Microsoft Teams Meeting Add-in for Outlook
    $TeamsAddin = 'HKLM:\Software\Microsoft\Office\Outlook\Addins\TeamsAddin.FastConnect'
    if (-not (Test-Path $TeamsAddin)) {
        Write-Output "[TeamsAddin.FastConnect] Registry Path Missing. Updating..."
        New-Item -Path "HKLM:\Software\Microsoft\Office\Outlook\Addins" -Name "TeamsAddin.FastConnect" -Force -ErrorAction Ignore
    }
    else {
        Write-Output "[TeamsAddin.FastConnect] Registry Path Confirmed."
    }

    # Teams Addin 'LoadBehavior' Function Lookup
    $Key_LoadBehavior = Test-RegistryValue -Path $TeamsAddin -Name 'LoadBehavior'
    $Value_LoadBehavior = Get-RegistryValue -Path $TeamsAddin -Name 'LoadBehavior'

    # Teams Addin 'LoadBehavior' Key and Value Validation
    if ($Key_LoadBehavior -and $Value_LoadBehavior -eq 3) {
        Write-Output "[LoadBehavior] Registry Key and Value Confirmed."
    }
    else {
        Write-Output "[LoadBehavior] Registry Key Missing or Value Incorrect. Updating..."
        New-ItemProperty -Path $TeamsAddin -Type "DWORD" -Name "LoadBehavior" -Value 3 -Force
    }

    # Teams Addin 'Description' Function Lookup
    $Key_Description = Test-RegistryValue -Path $TeamsAddin -Name 'Description'
    $Value_Description = Get-RegistryValue -Path $TeamsAddin -Name 'Description'

    # Teams Addin 'Description' Key and Value Validation
    if ($Key_Description -and $Value_Description -eq "Microsoft Teams Meeting Add-in for Microsoft Office") {
        Write-Output "[Description] Registry Key and Value Confirmed."
    }
    else {
        Write-Output "[Description] Registry Key Missing or Value Incorrect. Updating..."
        New-ItemProperty -Path $TeamsAddin -Type "String" -Name "Description" -Value "Microsoft Teams Meeting Add-in for Microsoft Office" -Force
    }

    # Teams Addin 'FriendlyName' Function Lookup
    $Key_FriendlyName = Test-RegistryValue -Path $TeamsAddin -Name 'FriendlyName'
    $Value_FriendlyName = Get-RegistryValue -Path $TeamsAddin -Name 'FriendlyName'

    # Teams Addin 'FriendlyName' Key and Value Validation
    if ($Key_FriendlyName -and $Value_FriendlyName -eq "Microsoft Teams Meeting Add-in for Microsoft Office") {
        Write-Output "[FriendlyName] Registry Key and Value Confirmed."
    }
    else {
        Write-Output "[FriendlyName] Registry Key Missing or Value Incorrect. Updating..."
        New-ItemProperty -Path $TeamsAddin -Type "String" -Name "FriendlyName" -Value "Microsoft Teams Meeting Add-in for Microsoft Office" -Force
    }

    # Stop Transcript and Output Log File
    Stop-Transcript

}
else {
    Write-Host "Microsoft Teams is not installed on this system, script will not continue." -ForegroundColor Red
    Exit
}
