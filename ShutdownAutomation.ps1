# Connect to Azure.
Connect-AzAccount -Identity

# Variable Definitions.
$allHostPools = @()
$allHostPools += (@{
        HostPool   = Get-AzWvdHostPool | Where-Object {$_.Name -like "hostpool-*-01-uks"} | Select-Object -ExpandProperty Name;
        HostPoolRG = Get-AzResourceGroup | Where-Object {$_.ResourceGroupName -like "*-avdresources-uks"} | Select-Object ResourceGroupName -ExpandProperty ResourceGroupName
    })
$Subscription = Get-AzSubscription | Select-Object -ExpandProperty ID

# Script Logic.
$Count = 0
while ($Count -lt $AllHostPools.Count) {
    $Pool = $AllHostPools[$Count].HostPool
    $PoolRG = $AllHostPools[$Count].HostPoolRG
    Write-Output "Host Pool: $Pool"
    Write-Output "Resource Group: $PoolRG"
    try {
        $ActiveSHs = (Get-AzWvdUserSession -ErrorAction Stop -SubscriptionId $Subscription -HostPoolName $Pool -ResourceGroupName $PoolRG).Name
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        Write-Error ("Error Getting User Sessions: " + $ErrorMessage)
        Break
    }
    $AllActive = @()
    foreach ($ActiveSH in $ActiveSHs) {
        $ActiveSH = ($ActiveSH -split { $_ -eq '.' -or $_ -eq '/' })[1]
        if ($ActiveSH -notin $AllActive) {
            $AllActive += $ActiveSH
        }
    }
    try {
        $RunningSessionHosts = (Get-AzWvdSessionHost -ErrorAction Stop -HostPoolName $Pool -ResourceGroupName $PoolRG | Where-Object { $_.AllowNewSession -eq $true } )
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        Write-Error ("Error Getting Running Session Hosts: " + $ErrorMessage)
        Break
    }
    $AvailableSessionHosts = ($RunningSessionHosts | Where-Object { $_.Status -eq "Available" })
    foreach ($SessionHost in $AvailableSessionHosts) {
        $SessionHostName = (($SessionHost).Name -split { $_ -eq '.' -or $_ -eq '/' })[1]
        if ($SessionHostName -notin $AllActive) {
            Write-Host "AVD Session Host $SessionHostName is not in use, Shutting Down."
            try {
                Write-Output "Stopping AVD Session Host: $SessionHostName"
                Get-AzVM -ErrorAction Stop -Name $SessionHostName | Stop-AzVM -ErrorAction Stop -Force -NoWait
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                Write-Error ("Error Stopping the Virtual Machine: " + $ErrorMessage)
                Break
            }
        }
        else {
            Write-Host "Server $SessionHostName has an active session(s), will not Shutdown."
        }
    }
    $Count += 1
}
