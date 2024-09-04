# Check Microsoft Teams Existence
Write-Output "Checking existence of Microsoft Teams..."
$Installed_TeamsClassic = Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' | Where-Object { ($_.DisplayName -like "*Teams*") -and ($_.Publisher -like "*Microsoft*") }
$Installed_TeamsNew = Get-AppxPackage | Where-Object { ($_.Name -eq "MSTeams") -and ($_.Publisher -like "*Microsoft*") }
if ($Installed_TeamsClassic -or $Installed_TeamsNew) {
    Write-Output "Microsoft Teams is installed, upgrade will now proceed."

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
        Write-Output "FSLogix version $($Ins_FSLogix) is below the required version of $($Req_FSLogix). Please upgrade FSLogix to the latest version, and then retry."
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

    # Uninstall Function for Microsoft Teams Machine-Wide Installs
    function Uninstall-TeamsClassic-MachineWide {
        $Paths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        )
        $MachineWide = Get-ChildItem -Path $Paths | Get-ItemProperty | Where-Object { $_.DisplayName -eq "Teams Machine-Wide Installer" }
        return $MachineWide
    }

    # Uninstall Function for Microsoft Teams Classic Per-User Installs
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

    # Uninstalls Microsoft Teams Classic Machine-Wide Installer
    Write-Output "Removing Teams Machine-Wide Installer..."
    $MachineWide = Uninstall-TeamsClassic-MachineWide
    if ($MachineWide) {
        Start-Process -FilePath "msiexec.exe" -Wait -ArgumentList "/passive", "/x$($MachineWide.PSChildName)", "/l*v `"$env:WINDIR\Temp\TeamsMachineWide_Uninstall.log`""
        Write-Output "Microsoft Teams Machine-Wide Installer was successfully uninstalled from the system."
    }
    else {
        Write-Output "Teams Machine-Wide Installer not found."
    }

    # Uninstalls Microsoft Teams Classic from Per-User Installs
    Write-Output "Identifying and Removing Microsoft Teams Classic Per-User Installations..."
    $AllUsers = Get-ChildItem -Path "$($env:SystemDrive)\Users" -Directory
    foreach ($User in $AllUsers) {
        Write-Output "Processing User: '$($User.Name)'."
        $LocalAppData = "$($env:SystemDrive)\Users\$($User.Name)\AppData\Local\Microsoft\Teams"
        $RoamingAppData = "$($env:SystemDrive)\Users\$($User.Name)\AppData\Roaming\Microsoft\Windows\Start Menu\Programs"
        $ProgramData = "$($env:ProgramData)\$($User.Name)\Microsoft\Teams"
        if (Test-Path "$LocalAppData\Current\Teams.exe") {
            Write-Output "Uninstalling Teams for User '$($User.Name)'."
            Uninstall-TeamsClassic -TeamsPath $LocalAppData
            Remove-Item -Path "$RoamingAppData\Microsoft Teams Classic.lnk"
        }
        elseif (Test-Path "$ProgramData\Current\Teams.exe") {
            Write-Output "Uninstalling Teams for User '$($User.Name)'."
            Uninstall-TeamsClassic -TeamsPath $ProgramData
            Remove-Item -Path "$RoamingAppData\Microsoft Teams Classic.lnk"
        }
        else {
            Write-Output "Teams Installation not found for User '$($User.Name)'."
        }
    }

    # Uninstall Microsoft Teams Appx Package
    Write-Output "Checking for Microsoft Teams Appx Package..."
    $MSTeamsPackage = Get-AppxPackage | Where-Object { ($_.Name -eq "MSTeams") -and ($_.Publisher -like "*Microsoft*") }
    if ($MSTeamsPackage) {
        Write-Output "Removing Microsoft Teams Appx Package."
        Remove-AppxPackage -Package $MSTeamsPackage
    }
    else {
        Write-Output "Microsoft Teams Appx Package not found."
    }
    
    # Delete Registry Key for Microsoft Teams URL Association
    Write-Output "Checking for Microsoft Teams URL Association Registry Key..."
    $TeamsAssociation = 'Registry::HKEY_CLASSES_ROOT\TeamsURL'
    if ((Test-Path $TeamsAssociation)) {
        Write-Output "[TeamsURL] Registry Path Exists. Deleting..."
        Remove-Item -Path $TeamsAssociation -Recurse -Force
    }
    else {
        Write-Output "[TeamsURL] Registry Path Not Found."
    }

    # Uninstall Microsoft Teams Meeting Add-in for Outlook
    Write-Output "Checking for Microsoft Teams Meeting Add-in for Outlook..."
    $TeamsAddinPackage = Get-Package | Where-Object { $_.Name -like "Microsoft Teams Meeting Add-in*" }
    if ($TeamsAddinPackage) {
        Write-Output "Removing Microsoft Teams Meeting Add-in for Outlook."
        Uninstall-Package -Name $TeamsAddinPackage.Name -Force | Out-Null
    }
    else {
        Write-Output "Microsoft Teams Meeting Add-in for Outlook not found."
    }

    Start-Sleep -Seconds 15

    # Register as Azure Virtual Desktop Environment
    Write-Output "Registering as Azure Virtual Desktop Environment..."
    $Key_WVDEnvironment = Test-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Teams' -Name 'IsWVDEnvironment'
    $Value_WVDEnvironment = Get-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Teams' -Name 'IsWVDEnvironment'
    if ($Key_WVDEnvironment -and $Value_WVDEnvironment -eq 1) {
        Write-Output "[ISWVDENVIRONMENT] Registry Key and Value Confirmed."
    }
    else {
        Write-Output "[ISWVDENVIRONMENT] Registry Key Missing or Value Incorrect. Updating..."
        New-Item -Path "HKLM:\SOFTWARE\Microsoft" -Name "Teams" -Force -ErrorAction Ignore | Out-Null
        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Teams" -Name "IsWVDEnvironment" -Value 1 -Force | Out-Null
    }

    # Allow Side-Loading Trusted Applications
    Write-Output "Allow Side-Loading Trusted Applications..."
    $Key_AllowAllTrustedApps = Test-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\Appx' -Name 'AllowAllTrustedApps'
    $Value_AllowAllTrustedApps = Get-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\Appx' -Name 'AllowAllTrustedApps'
    if ($Key_AllowAllTrustedApps -and $Value_AllowAllTrustedApps -eq 1) {
        Write-Output "[AllowAllTrustedApps] Registry Key and Value Confirmed."
    }
    else {
        Write-Output "[AllowAllTrustedApps] Registry Key Missing or Value Incorrect. Updating..."
        New-Item -Path "HKLM:\Software\Policies\Microsoft\Windows" -Name "Appx" -Force -ErrorAction Ignore | Out-Null
        New-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\Appx" -Name "AllowAllTrustedApps" -Value 1 -Force | Out-Null
    }

    $ProgressPreference = 'SilentlyContinue'

    # Downloading and Installing Remote Desktop WebRTC Redirector Service
    Write-Output "Downloading and Installing Remote Desktop WebRTC Redirector Service..."
    Invoke-WebRequest -Uri "https://aka.ms/msrdcwebrtcsvc/msi" -OutFile "$($env:WINDIR)\Temp\MSRDCWEBRTCSVC_x64.msi"
    Start-Process -FilePath "msiexec.exe" -Wait -ArgumentList "/i", "`"$env:WINDIR\Temp\MSRDCWEBRTCSVC_x64.msi`"", "/l*v `"$env:WINDIR\Temp\MSRDCWEBRTCSVC_Install.log`"", "/qn /norestart"

    # Downloading and Installing WebView2 Runtime
    Write-Output "Downloading and Installing WebView2 Runtime..."
    Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/p/?LinkId=2124703" -OutFile "$($env:WINDIR)\Temp\MicrosoftEdgeWebview2Setup.exe"
    Start-Process -FilePath "$($env:WINDIR)\Temp\MicrosoftEdgeWebview2Setup.exe" -Wait -ArgumentList "/silent /install" -ErrorAction SilentlyContinue

    # Downloading and Installing Microsoft Teams
    Write-Output "Downloading and Installing Microsoft Teams..."
    Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2243204&clcid=0x409" -OutFile "$($env:WINDIR)\Temp\TeamsBootstrapper.exe"
    Start-Process -FilePath "$($env:WINDIR)\Temp\TeamsBootstrapper.exe" -Wait -ArgumentList "-p" -PassThru -ErrorAction SilentlyContinue

    # Disable Microsoft Teams Automatic Updates
    Write-Output "Disabling Microsoft Teams Automatic Updates..."
    $Key_DisableAutomaticUpdates = Test-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Teams' -Name 'disableAutoUpdate'
    $Value_DisableAutomaticUpdates = Get-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Teams' -Name 'disableAutoUpdate'
    if ($Key_DisableAutomaticUpdates -and $Value_DisableAutomaticUpdates -eq 1) {
        Write-Output "[disableAutoUpdate] Registry Key and Value Confirmed."
    }
    else {
        Write-Output "[disableAutoUpdate] Registry Key Missing or Value Incorrect. Updating..."
        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Teams" -Name "disableAutoUpdate" -Value 1 -Force | Out-Null
    }

    Start-Sleep -Seconds 15

    # Microsoft Teams Meeting Add-in for Outlook
    if (-not ($NewTeamsPackageVersion = (Get-AppxPackage -Name MSTeams).Version)) {
        Write-Output "Microsoft Teams (New) Package is not found, this must be installed to continue."
        exit 1
    }
    Write-Output "Microsoft Teams (New) Package Version: $($NewTeamsPackageVersion)."

    $TMAPath = "{0}\WindowsApps\MSTeams_{1}_x64__8wekyb3d8bbwe\MicrosoftTeamsMeetingAddinInstaller.msi" -f $env:ProgramFiles, $NewTeamsPackageVersion
    if (-not ($TMAVersion = (Get-AppLockerFileInformation -Path $TMAPath | Select-Object -ExpandProperty Publisher).BinaryVersion)) {
        Write-Output "Installer for the Microsoft Teams Meeting Add-in cannot be found in '$($TMAPath)', unable to continue."
        exit 1
    }
    Write-Output "Microsoft Teams Meeting Add-in Version: $($TMAVersion)."
    
    $TargetDir = "{0}\Microsoft\TeamsMeetingAddin\{1}\" -f ${env:ProgramFiles(x86)}, $TMAVersion
    $Params = '/i "{0}" TARGETDIR="{1}" /qn ALLUSERS=1' -f $TMAPath, $TargetDir
    Write-Output "Installing Microsoft Teams Meeting Add-in for Outlook..."
    Start-Process msiexec.exe -ArgumentList $Params

    # Registry Keys for Microsoft Teams Meeting Add-in for Outlook
    $TeamsAddin = 'HKLM:\Software\Microsoft\Office\Outlook\Addins\TeamsAddin.FastConnect'
    if (-not (Test-Path $TeamsAddin)) {
        Write-Output "[TeamsAddin.FastConnect] Registry Path Missing. Updating..."
        New-Item -Path "HKLM:\Software\Microsoft\Office\Outlook\Addins" -Name "TeamsAddin.FastConnect" -Force -ErrorAction Ignore | Out-Null
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
        New-ItemProperty -Path $TeamsAddin -Type "DWORD" -Name "LoadBehavior" -Value 3 -Force | Out-Null
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
        New-ItemProperty -Path $TeamsAddin -Type "String" -Name "Description" -Value "Microsoft Teams Meeting Add-in for Microsoft Office" -Force | Out-Null
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
        New-ItemProperty -Path $TeamsAddin -Type "String" -Name "FriendlyName" -Value "Microsoft Teams Meeting Add-in for Microsoft Office" -Force | Out-Null
    }

    # Stop Transcript and Output Log File
    Stop-Transcript
}
else {
    Write-Output "Microsoft Teams is not installed on this system, script will not continue."
    exit
}
