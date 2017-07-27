<# 
.DESCRIPTION
Walksthrough resource groups in an Azure subscription and calculates the storage account and core count
 
#>

$allRGs = (Get-AzureRmResourceGroup).ResourceGroupName
Write-Warning "Found $($allRGs | Measure-Object | Select -ExpandProperty Count) total RGs"

foreach ($rgName in $allRGs)
{
    $rg = Get-AzureRmResourceGroup -Name $rgName
    $resources = Find-AzureRmResource -ResourceGroupNameEquals $rgName

    # Owner
    $owner = "Unknown"
    if ($rg.Tags)
    {
        $owner = $rg.Tags["CREATED-BY"]
    }

    $numResources = $resources | Measure-Object | Select -ExpandProperty Count
    $isEmpty = $numResources -eq 0

    # Storage Account
    $numSA = $resources | Where {$_.ResourceType -eq "Microsoft.Storage/storageAccounts" } | Measure-Object | Select -ExpandProperty Count

    # Cores
    $numCores = 0

    #   vm
    $vmNames = $resources | Where {$_.ResourceType -eq "Microsoft.Compute/virtualMachines" } | Select -ExpandProperty Name
    foreach ($vmName in $vmNames) {
        $size = (Get-AzureRmVM -ResourceGroupName $rgName -Name $vmName).HardwareProfile.VmSize
        $numCores += Get-AzureRmVmSize -location $rg.Location | ?{ $_.name -eq $size } | Select -ExpandProperty NumberOfCores
    }

    #   vmss
    $vmssNames = $resources | Where {$_.ResourceType -eq "Microsoft.Compute/virtualMachineScaleSets" } | Select -ExpandProperty Name
    foreach ($vmssName in $vmssNames) {
        $vmss = Get-AzureRmVmss -ResourceGroupName $rgName -VMScaleSetName $vmssName
        $numCores += (Get-AzureRmVmSize -location $rg.Location | ?{ $_.name -eq $vmss.Sku.Name } | Select -ExpandProperty NumberOfCores) * $vmss.Sku.Capacity
    }

    Write-Host "$rgName, $rg.Location, $owner, $isEmpty, $numSA, $numCores"
}


