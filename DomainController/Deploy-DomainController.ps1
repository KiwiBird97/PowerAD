<#
.SYNOPSIS
    Automates deployment of a new Active Directory forest/domain on a
    Windows Server 2022 machine (first domain controller).

.DESCRIPTION
    Installs the AD-Domain-Services Windows feature and promotes the server
    to a domain controller for a brand-new forest, using values from
    Config\Config.psd1. The server will reboot automatically once promotion
    completes unless -NoRestart is specified.

.PARAMETER ConfigPath
    Path to the PowerAD Config.psd1 file. Defaults to ..\Config\Config.psd1.

.PARAMETER NoRestart
    Prepares and validates promotion but does not restart the server
    automatically after DCPromo completes.

.EXAMPLE
    .\Deploy-DomainController.ps1
    Installs AD DS using the default configuration file.

.NOTES
    Must be run locally on the target Windows Server 2022 machine, from an
    elevated PowerShell session. Requires a restart to complete promotion.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Safe mode password is supplied by configuration for unattended domain bootstrap.')]
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot '..\Config\Config.psd1'),
    [switch]$NoRestart
)

Import-Module (Join-Path $PSScriptRoot '..\Modules\PowerAD.Common.psm1') -Force

Assert-RunAsAdministrator
$config = Import-PowerADConfig -Path $ConfigPath
$domain = $config.Domain

Write-PowerADLog "Deploying new AD forest '$($domain.DNSName)' (NetBIOS: $($domain.NetBIOSName))" -Level INFO

# 1. Install the required Windows features -----------------------------------
$features = 'AD-Domain-Services', 'DNS', 'RSAT-AD-PowerShell', 'RSAT-AD-AdminCenter', 'RSAT-DNS-Server', 'GPMC'
Write-PowerADLog "Installing Windows features: $($features -join ', ')"
foreach ($feature in $features) {
    $result = Install-WindowsFeature -Name $feature -IncludeManagementTools -ErrorAction Stop
    if ($result.Success) {
        Write-PowerADLog "Feature '$feature' installed (RestartNeeded: $($result.RestartNeeded))." -Level SUCCESS
    }
}

# 2. Promote the server to a domain controller -------------------------------
Import-Module ADDSDeployment -ErrorAction Stop

$safeModePwd = ConvertTo-SecureString $domain.SafeModeAdminPwd -AsPlainText -Force

$installParams = @{
    CreateDnsDelegation           = $false
    DatabasePath                  = $domain.DatabasePath
    DomainMode                    = $domain.DomainFunctionalLevel
    ForestMode                    = $domain.ForestFunctionalLevel
    DomainName                    = $domain.DNSName
    DomainNetbiosName              = $domain.NetBIOSName
    SafeModeAdministratorPassword = $safeModePwd
    InstallDns                    = $true
    LogPath                       = $domain.LogPath
    NoRebootOnCompletion           = [bool]$NoRestart
    SysvolPath                    = $domain.SysvolPath
    Force                          = $true
}

if ($PSCmdlet.ShouldProcess($domain.DNSName, 'Install new AD Forest / Promote to Domain Controller')) {
    Write-PowerADLog 'Starting forest creation. The server will restart automatically unless -NoRestart was specified.' -Level WARN
    Install-ADDSForest @installParams
    Write-PowerADLog 'Domain controller promotion complete.' -Level SUCCESS
}
