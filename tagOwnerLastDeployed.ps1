<# 
.DESCRIPTION 
Ascertains the owner of a resource group through Azure Event Logs.
If an owner is found, a 'CREATED-BY' tag is applied to the resource group.
 
.PARAMETER dryRun
If true, changes will not be applied to Azure. The default is false.

#>

param (
    [switch]$dryRun = $false
)

$allRGs = (Get-AzureRmResourceGroup).ResourceGroupName
Write-Warning "Found $($allRGs | Measure-Object| Select-Object -ExpandProperty Count) total RGs"

$aliasedRGs = (Find-AzureRmResourceGroup -Tag @{ "CREATED-BY" = $null }).Name
Write-Warning "Found $($aliasedRGs | Measure-Object| Select-Object -ExpandProperty Count) tagged RGs"
  
$notAliasedRGs = $allRGs | ?{-not ($aliasedRGs -contains $_)}
Write-Warning "Found $($notAliasedRGs | Measure-Object | Select-Object -ExpandProperty Count) un-tagged RGs"

foreach ($rg in $notAliasedRGs)
{
    $currentTime = Get-Date
    $endTime = $currentTime
    $startTime = $endTime.AddDays(-7)
        
    $callers = Get-AzureRmLog -ResourceGroup $rg -StartTime $startTime -EndTime $endTime -WarningAction SilentlyContinue |
        Where-Object {$_.Authorization.Action -eq "Microsoft.Resources/deployments/write" -or $_.Authorization.Action -eq "Microsoft.Resources/subscriptions/resourcegroups/write" } | 
        Select-Object -ExpandProperty Caller | 
        Group-Object | 
        Sort-Object  | 
        Select-Object -ExpandProperty Name

    if ($callers)
    {
        $owner = $callers | Select-Object -First 1
        $alias = $owner -replace "@microsoft.com",""

        $tags = (Get-AzureRmResourceGroup -Name $rg).Tags
        $tags += @{ "CREATED-BY"=$alias }

        $rg + ", " + $alias
        if (-not $dryRun) 
        {
            Set-AzureRmResourceGroup -Name $rg -Tag $tags
        }
        else
        {
            Write-Warning "Set-AzureRmResourceGroup -Name $rg -Tag $tags"
        }
    } 
    else 
    {
        $rg + ", Unknown"
    }   
}
