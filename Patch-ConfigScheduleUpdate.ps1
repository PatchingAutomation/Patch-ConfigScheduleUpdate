<#
.SYNOPSIS
 ConfigScheduleUpdate.ps1 use to create or update a update schedule in Azure Update management.

.DESCRIPTION
  This script is intended to create or update a update schedule in Azure Update management. 

.PARAMETER ScheduleName
  A string for update schedule name, will append the date time (yyyy-MMdd-hhmm) w/o '-Update' switch 

.PARAMETER StartTime
  A string for start time of the update schedule. 
  e.g. "2022-5-30T21:00"

.PARAMETER AddMinutes
  An int for add minutes to start update schedule, the default value is 10 mins w/o StartTime.

.PARAMETER Update
  A switch to update the update schedule, otherwise will renew a update schedule.
   
.PARAMETER Duration
  An int for the Patch Window, the default value is 200 mins.

.PARAMETER RebootSetting
  An int for reboot setting, the defaule value is 0. (IfRequired:0;Never:1;Always:2;RebootOnly:3)

.PARAMETER IncludedUpdateClassification
  An array int for include update classification, the defaule value is @(1).
  ==========================================================================
  (Critical:1;Security:2;UpdateRollup:4;FeaturePack:8;ServicePack:16;Definition:32;Tools:64;Updates:128)
  e.g. @(1,2,4,8,16,32,64,128) in local powershell
  e.g. [1,2,4,8,16,32,64,128] in Azure runbook

.PARAMETER ExcludedKbNumber
  An array of string for exclude Kb number.
  e.g. @("168934","168935") in local powershell
  e.g. ["168934","168935"] in Azure runbook

.PARAMETER IncludedKbNumber
  An array of string for include Kb number.
  e.g. @("168934","168935") in local powershell
  e.g. ["168934","168935"] in Azure runbook

.EXAMPLE (running locally)
get-help .\ConfigScheduleUpdate.ps1 -Full
Dump this full help

.EXAMPLE (running Azure)
.\ConfigScheduleUpdate.ps1 -ScheduleName FE-Batch1 -Scope ["/subscriptions/82282963-fef0-4507-aa83-c0a418691820/resourceGroups/buildss"] -Tags @{tag1 = @("tag1","Tag2")} -Update true
Update a update schedule use Azure query

.EXAMPLE (running locally)
.\ConfigScheduleUpdate.ps1 -ScheduleName FE-Batch1 -Scope @("/subscriptions/82282963-fef0-4507-aa83-c0a418691820/resourceGroups/buildss") -Tags @{tag1 = @("tag1","Tag2")}
Create a update schedule use Azure query

#>
#requires -Modules Az.Accounts
#requires -Modules Az.Automation
param(
    [parameter(mandatory=$true)]
    [string]$ScheduleName,

    [parameter(mandatory=$true)]
    [string]$VariableName = "ConfigScheduleUpdate",

    [parameter(mandatory=$false)]
    [string]$ServerListVariableName = $null,

    [parameter(mandatory=$false)]
    [string]$StartTime = $null,

    [parameter(mandatory=$false)]
    [int]$AddMinutes = -1,
    
    [parameter(mandatory=$false)]
    [bool]$Update = $false,

    [parameter(mandatory=$false)]
    [int]$RebootSetting = -1,

    [parameter(mandatory=$false)]
    [int[]]$IncludedUpdateClassification = $null,

    [parameter(mandatory=$false)]
    [String[]]$ExcludedKbNumber = $null,

    [parameter(mandatory=$false)]
    [String[]]$IncludedKbNumber = $null
    
)
<# Parameter def End #>
#******************************************************************************
<#  Global State Configuration Start #>
#******************************************************************************

<#  
    Script Initialization Start 
    This script doesn't need to inherit Global Variable from the parent context. We initialize it as a new Hash object and share between functions to simplify coding.
#>
$Global:ConfigScheduleUpdate = @{}
$Global:ConfigScheduleUpdate['ExitCode'] = 0
$Global:ConfigScheduleUpdate['RunOnAzure'] = 0
$Global:ConfigScheduleUpdate['JsonData'] = $null
#******************************************************************************
<# Function Definitions Start #>
#******************************************************************************

function Exit-WithCode ([Int]$exitcode)
{ 
    <#
        .Synopsis 
            Wrapping the exit code when exit script.

        .Description
            The function addresses the exit code in the test or automation environment.

        .PARAMETER exitcode
            The exit code needs to deal with.

        .OUTPUTS
            No output.
    #>
    $Global:ConfigScheduleUpdate.ExitCode = $exitcode
    Exit $exitcode;		
}
<# Function Definitions End #>
#------------------------------------------------------------------------------
#******************************************************************************
<# Main Script Start #>
#******************************************************************************
try
{
    #========Login ============
    if ("AzureAutomation/" -eq $env:AZUREPS_HOST_ENVIRONMENT) {
        Write-Output "This script ConfigScheduleUpdate run on Azure Runbook"
        $AzureContext = (Connect-AzAccount -Identity).context
        $Global:ConfigScheduleUpdate['RunOnAzure'] = 1
        $content = Get-AutomationVariable -Name $VariableName
        $Global:ConfigScheduleUpdate.JsonData = $content | ConvertFrom-Json        
    }else{
        Set-StrictMode -Version Latest
        $here = if($MyInvocation.MyCommand.PSObject.Properties.Item("Path") -ne $null){(Split-Path -Parent $MyInvocation.MyCommand.Path)}else{$(Get-Location).Path}
        pushd $here
        Write-Output "This script ConfigScheduleUpdate running locally"
        if(Test-Path "$here\azurecontext.json"){
            $AzureContext = Import-AzContext -Path "$here\azurecontext.json"
        }else{
            $AzureContext = Connect-AzAccount -ErrorAction Stop
            Save-AzContext -Path "$here\azurecontext.json"
        }
        if([string]::IsNullOrEmpty($VariableName)){
            Write-Output "Load default config from $here\ConfigScheduleUpdate.json "
            $Global:ConfigScheduleUpdate.JsonData = (Get-content -Path "$here\ConfigScheduleUpdate.json") | ConvertFrom-Json
        }else{
            Write-Output "Load config from $VariableName "
            $Global:ConfigScheduleUpdate.JsonData = (Get-content -Path $VariableName) | ConvertFrom-Json
        }
    }
    $s = $null
    foreach($schedule in $Global:ConfigScheduleUpdate.JsonData.Schedule){
        if($schedule.ScheduleName -ieq $ScheduleName){
            $s = $schedule
            break
        }        
    }
    if($s -ne $null){
	if($Global:ConfigScheduleUpdate.RunOnAzure -eq 1){
            if(![string]::IsNullOrEmpty($ServerListVariableName)){
                Write-Output "Get automation variable from $ServerListVariableName"
                $Global:ConfigScheduleUpdate['ServerListVariable'] = Get-AutomationVariable -Name $ServerListVariableName
                $s.ScheduleName = "$($s.ScheduleName)_$($ServerListVariableName)"
            }elseif(![string]::IsNullOrEmpty($s.ServerListVariableName)){
			    Write-Output "Get automation variable from $($s.ServerListVariableName)"
                $Global:ConfigScheduleUpdate['ServerListVariable'] = Get-AutomationVariable -Name $($s.ServerListVariableName)
                $s.ScheduleName = "$($s.ScheduleName)_$($s.ServerListVariableName)"
        	}
    	}
        Write-Output "Processing $($s.ScheduleName) under AutomationAccountName: $($s.AutomationAccountName) ResourceGroupName: $($s.ResourceGroupName) Subscription: $($s.Subscription)"
        if(![string]::IsNullOrEmpty($s.ServerList) -and $s.ServerList.GetType().BaseType.Name -eq "Array"){
            $servers = $s.ServerList -join ','
        }elseif(![string]::IsNullOrEmpty($s.ServerList)){
            $servers = $s.ServerList
        }
        if(![string]::IsNullOrEmpty($Global:ConfigScheduleUpdate['ServerListVariable'])){
            if([string]::IsNullOrEmpty($servers)){
                $servers = ($Global:ConfigScheduleUpdate['ServerListVariable'].split("`n") -join ',')
             }else{
                $servers = $servers + ',' + ($Global:ConfigScheduleUpdate['ServerListVariable'].split("`n") -join ',')
             }
        }
        Write-Output "VMs: $($servers)"
        $scope = $s.Scope
		$location = $s.Location
        if($scope -ne $null -and $s.Tags -ne $null){
            $Tags = @{}
            $s.Tags.psobject.properties | ForEach-Object { 
                $Tags[$_.Name] = $_.Value 
            }
        }else{
            $Tags = $null
        }
        
        if($s.TagOperators -ne $null -and ($s.TagOperators -eq 0 -or $s.TagOperators -eq 1)){
            $TagOperators = $s.TagOperators
        }else{
            $TagOperators = 0
        }
        Write-Output "AzureQuery scope: $($Scope); Tags: $($Tags); TagOperators: $($TagOperators)"

        if([string]::IsNullOrEmpty($StartTime)){
            $StartTime = $s.StartTime
        }
        if($AddMinutes -eq -1){
            if($s.AddMinutes -ne $null -and $s.AddMinutes -gt 0){
                $AddMinutes = $s.AddMinutes
            }else{
                $AddMinutes = 0
            }
        }
        if($s.Duration -ne $null -and $s.Duration -gt 0){
            $Duration = $s.Duration
        }else{
            $Duration = 120
        }
        if($s.Update -ne $null){
            $Update = $s.Update
        }else{
            $Update = $false
        }
        Write-Output "StartTime: $($StartTime); AddMinutes: $($AddMinutes); Duration: $($Duration); Update: $($Update)"
        $PreTaskRunbookName = $s.PreTaskRunbookName
        if($PreTaskRunbookName -ne $null -and $s.PreTaskRunbookParameter -ne $null){
            $PreTaskRunbookParameter = @{}
            $s.PreTaskRunbookParameter.psobject.properties | ForEach-Object { 
                $PreTaskRunbookParameter[$_.Name] = $_.Value 
            }
        }else{
            $PreTaskRunbookParameter = $null
        }
        $PostTaskRunbookName = $s.PostTaskRunbookName
        if($PostTaskRunbookName -ne $null -and $s.PostTaskRunbookParameter -ne $null){
            $PostTaskRunbookParameter = @{}
            $s.PostTaskRunbookParameter.psobject.properties | ForEach-Object { 
                $PostTaskRunbookParameter[$_.Name] = $_.Value 
            }
        }else{
            $PostTaskRunbookParameter = $null
        }
        Write-Output "PreTaskRunbookName: $($PreTaskRunbookName); PreTaskRunbookParameter: $($PreTaskRunbookParameter); PostTaskRunbookName: $($PostTaskRunbookName); PostTaskRunbookParameter: $($PostTaskRunbookParameter)"
        if($RebootSetting -eq -1){
            if($s.RebootSetting -ne $null){
                $RebootSetting = $s.RebootSetting
            }else{
                $RebootSetting = 0
            }
        }
        if($IncludedUpdateClassification -eq $null){
            $IncludedUpdateClassification = $s.IncludedUpdateClassification
        }
        if($ExcludedKbNumber -eq $null){
            $ExcludedKbNumber = $s.ExcludedKbNumber
        }
        if($IncludedKbNumber -eq $null){
            $IncludedKbNumber = $s.IncludedKbNumber
        }
        Write-Output "RebootSetting: $($RebootSetting); IncludedUpdateClassification: $($IncludedUpdateClassification); ExcludedKbNumber: $($ExcludedKbNumber); IncludedKbNumber: $($IncludedKbNumber)"
        Write-Output "==================Running scipt ScheduleUpdate.ps1========================"
        .\Patch-ScheduleUpdate.ps1 -ScheduleName $($s.ScheduleName) -Subscription $($s.Subscription) -ResourceGroupName $($s.ResourceGroupName) -AutomationAccountName $($s.AutomationAccountName) `
            -ServerList $servers -Scope $scope -Location $location -Tags $Tags -TagOperators $TagOperators `
            -StartTime $StartTime -AddMinutes $AddMinutes -Duration $Duration -Update $Update `
            -PreTaskRunbookName $PreTaskRunbookName -PreTaskRunbookParameter $PreTaskRunbookParameter -PostTaskRunbookName $PostTaskRunbookName -PostTaskRunbookParameter $PostTaskRunbookParameter `
            -RebootSetting $RebootSetting -IncludedUpdateClassification $IncludedUpdateClassification -ExcludedKbNumber $ExcludedKbNumber -IncludedKbNumber $IncludedKbNumber
        Write-Output "==================Finished ran scipt ScheduleUpdate.ps1==================="
    }else{
        #Write-Output "Can't find $ScheduleName from ($($Global:ConfigScheduleUpdate.JsonData.Schedule.ScheduleName))"
	    throw "Can't find $ScheduleName from ($($Global:ConfigScheduleUpdate.JsonData.Schedule.ScheduleName))"
    }
}
catch
{
    Write-Error "Exception while executing the main script : $($_.Exception)"
    throw "Exception: $_"
}
finally
{
    if($Global:ConfigScheduleUpdate.RunOnAzure -eq 0){
        popd
    }
}

#------------------------------------------------------------------------------

<# Main Script End #>