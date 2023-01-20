# Connect to Azure.
Connect-AzAccount -Identity

# Variable Definitions.
$SubscriptionID = Get-AzSubscription | Select-Object -ExpandProperty ID
$StorageAccount = Get-AzStorageAccount | Where-Object { ($_.ResourceGroupName -like '*fileservers*') -and ($_.Kind -eq 'FileStorage') } | Select-Object -ExpandProperty StorageAccountName
$ResourceGroup = Get-AzStorageAccount | Where-Object { ($_.ResourceGroupName -like '*fileservers*') -and ($_.Kind -eq 'FileStorage') } | Select-Object -ExpandProperty ResourceGroupName
$FileShare = Get-AzRmStorageShare -ResourceGroupName $ResourceGroup -StorageAccountName $StorageAccount | Select-Object -ExpandProperty Name

# Set Subscription and Import Az Modules.
Set-AzContext -Subscription $SubscriptionID
Import-Module -Name Az.Accounts
Import-Module -Name Az.Storage

# Get File Share.
$PFS = Get-AzRmStorageShare -ResourceGroupName $ResourceGroup -StorageAccountName $StorageAccount -Name $FileShare -GetShareUsage

# Get Provisioned Capacity and Used Capacity.
$ProvisionedCapacity = $PFS.QuotaGiB
$UsedCapacity = $PFS.ShareUsageBytes
Write-Host "Provisioned Capacity:" $ProvisionedCapacity
Write-Host "Share Usage Bytes:" $UsedCapacity

# Get Storage Account.
$StorageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroup -AccountName $StorageAccount

# Calculate if less than 20% of Provisioned Capacity is remaining, increase by 20%.
if (($ProvisionedCapacity - ($UsedCapacity / ([Math]::Pow(2, 30)))) -lt ($ProvisionedCapacity * 0.2)) {
    $Quota = $ProvisionedCapacity * 1.2
    Update-AzRmStorageShare -StorageAccount $StorageAccount -Name $FileShare -QuotaGiB $Quota
    $ProvisionedCapacity = $Quota
}
Write-Host "New Provisioned Capacity:" $ProvisionedCapacity
