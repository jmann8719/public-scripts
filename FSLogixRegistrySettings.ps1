<#
.SYNOPSIS
    This script creates the required FSLogix Registry Keys for Azure Virtual Desktop Session Hosts.

.DESCRIPTION
    This script enforces a baseline configuration for FSLogix on Azure Virtual Desktop Session Hosts by validating a defined set of registry keys and values.
    For each setting, it ensures the registry path exists and creates or corrects the value if it is missing or misconfigured.
    The script is idempotent, making it safe to run repeatedly to maintain consistent FSLogix behaviour across all Azure Virtual Desktop Session Hosts.

.EXAMPLE
    An example of how to run the script:
    PS C:\> .\FSLogixRegistrySettings.ps1

.NOTES
    Author: Jonathan Mann
    Date: 01st March 2026
    Version: 1.0

.LINK
    https://learn.microsoft.com/en-us/fslogix/concepts-configuration-examples
    https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings
#>

$RegistryKeys = @(
    @{
        Path  = 'HKLM:\SOFTWARE\FSLogix\Apps'
        Name  = 'CleanupInvalidSessions'
        Type  = 'DWORD'
        Value = 1
    },
    @{
        Path  = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        Name  = 'DeleteLocalProfileWhenVHDShouldApply'
        Type  = 'DWORD'
        Value = 1
    },
    @{
        Path  = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        Name  = 'Enabled'
        Type  = 'DWORD'
        Value = 0
    },
    @{
        Path  = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        Name  = 'FlipFlopProfileDirectoryName'
        Type  = 'DWORD'
        Value = 1
    },
    @{
        Path  = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        Name  = 'LockedRetryCount'
        Type  = 'DWORD'
        Value = 3
    },
    @{
        Path  = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        Name  = 'LockedRetryInterval'
        Type  = 'DWORD'
        Value = 15
    },
    @{
        Path  = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        Name  = 'PreventLoginWithFailure'
        Type  = 'DWORD'
        Value = 1
    },
    @{
        Path  = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        Name  = 'PreventLoginWithTempProfile'
        Type  = 'DWORD'
        Value = 1
    },
    @{
        Path  = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        Name  = 'ReAttachIntervalSeconds'
        Type  = 'DWORD'
        Value = 15
    },
    @{
        Path  = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        Name  = 'ReAttachRetryCount'
        Type  = 'DWORD'
        Value = 3
    },
    @{
        Path  = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        Name  = 'RedirXMLSourceFolder'
        Type  = 'REG_SZ'
        Value = ''
    },
    @{
        Path  = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        Name  = 'RoamIdentity'
        Type  = 'DWORD'
        Value = 1
    },
    @{
        Path  = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        Name  = 'VHDLocations'
        Type  = 'REG_SZ'
        Value = ''
    },
    @{
        Path  = 'HKLM:\SOFTWARE\FSLogix\Profiles'
        Name  = 'VolumeType'
        Type  = 'REG_SZ'
        Value = 'VHDX'
    }
)

# Loop and Process Registry Keys
foreach ($Key in $RegistryKeys) {
    # Create Registry Path if required
    if (-not (Test-Path $Key.Path)) {
        Write-Output "Creating Registry Key: $($Key.Path)"
        New-Item -Path $Key.Path -Force | Out-Null
    }
    # Read Registry Key and Value
    $CurrentValue = Get-ItemProperty -Path $Key.Path -Name $Key.Name -ErrorAction SilentlyContinue
    # Default to Updating Value
    $NeedsUpdate = $true
    # Skip if Registry Key Value Matches
    if ($null -ne $CurrentValue) {
        if ($CurrentValue.$($Key.Name) -eq $Key.Value) {
            $NeedsUpdate = $false
        }
    }
    # Create or Update Registry Key and/or Value
    if ($NeedsUpdate) {
        Write-Output "Setting $($Key.Path)\$($Key.Name) = $($Key.Value)"
        # Write Registry Key Value if Type 'DWORD'
        if ($Key.Type -eq 'DWORD') {
            New-ItemProperty -Path $Key.Path -Name $Key.Name -Value $Key.Value -PropertyType DWORD -Force | Out-Null
        }
        # Write Registry Key Value if Type 'REG_SZ'
        elseif ($Key.Type -eq 'REG_SZ') {
            New-ItemProperty -Path $Key.Path -Name $Key.Name -Value $Key.Value -PropertyType String -Force | Out-Null
        }
    }
    else {
        # Registry Key Validation
        Write-Output "OK: $($Key.Path)\$($Key.Name)"
    }
}
