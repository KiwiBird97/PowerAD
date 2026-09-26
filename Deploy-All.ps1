<#
.SYNOPSIS
    Master orchestrator that deploys the entire PowerAD environment in order:
    OUs -> Security Groups -> Users -> Group Policy Objects.

.DESCRIPTION
    Run this AFTER the domain controller has been promoted and rebooted
    (see DomainController\Deploy-DomainController.ps1), from a session that
    has the ActiveDirectory and GroupPolicy modules available (i.e. run on
    the DC itself, or a management machine with RSAT installed).

.PARAMETER ConfigPath
    Path to the PowerAD Config.psd1 file, forwarded to every sub-script.

.PARAMETER SkipGroupPolicy
    Skips GPO creation/linking (useful for quick lab setups).

.PARAMETER UsersCsvPath
    Optional path to a CSV of users to provision instead of the users listed
    in Config.psd1 (forwarded to New-ADUsers.ps1 -CsvPath).

.EXAMPLE
    .\Deploy-All.ps1
    Deploys OUs, groups, users, and GPOs using Config.psd1 defaults.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'Config\Config.psd1'),
    [switch]$SkipGroupPolicy,
    [string]$UsersCsvPath
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Modules\PowerAD.Common.psm1') -Force

Write-PowerADLog '=== PowerAD: Starting full environment deployment ===' -Level INFO

Write-PowerADLog 'Step 1/4: Organizational Units'
& (Join-Path $PSScriptRoot 'OUs\New-OUStructure.ps1') -ConfigPath $ConfigPath

Write-PowerADLog 'Step 2/4: Security Groups'
& (Join-Path $PSScriptRoot 'Groups\New-SecurityGroups.ps1') -ConfigPath $ConfigPath

Write-PowerADLog 'Step 3/4: User Provisioning'
if ($UsersCsvPath) {
    & (Join-Path $PSScriptRoot 'Users\New-ADUsers.ps1') -ConfigPath $ConfigPath -CsvPath $UsersCsvPath
}
else {
    & (Join-Path $PSScriptRoot 'Users\New-ADUsers.ps1') -ConfigPath $ConfigPath
}

if (-not $SkipGroupPolicy) {
    Write-PowerADLog 'Step 4/4: Group Policy Objects'
    & (Join-Path $PSScriptRoot 'GroupPolicy\Deploy-GroupPolicies.ps1') -ConfigPath $ConfigPath
}
else {
    Write-PowerADLog 'Step 4/4: Group Policy Objects (skipped via -SkipGroupPolicy)' -Level WARN
}

Write-PowerADLog '=== PowerAD: Environment deployment complete ===' -Level SUCCESS
