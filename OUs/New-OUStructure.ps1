<#
.SYNOPSIS
    Creates the Organizational Unit (OU) hierarchy defined in Config\Config.psd1.

.DESCRIPTION
    Reads the OrganizationalUnits array from the PowerAD configuration file and
    creates each OU (including nested parents) if it does not already exist.
    Idempotent: safe to re-run at any time.

.PARAMETER ConfigPath
    Path to the PowerAD Config.psd1 file.

.PARAMETER ProtectFromDeletion
    Enables the "protect object from accidental deletion" flag on created OUs.
    Defaults to $true.

.EXAMPLE
    .\New-OUStructure.ps1
    Creates every OU listed in Config.psd1 under the domain's default naming context.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot '..\Config\Config.psd1'),
    [bool]$ProtectFromDeletion = $true
)

Import-Module (Join-Path $PSScriptRoot '..\Modules\PowerAD.Common.psm1') -Force
Assert-ModuleAvailable -Name ActiveDirectory
Import-Module ActiveDirectory -ErrorAction Stop

$config = Import-PowerADConfig -Path $ConfigPath
$baseDN = Get-PowerADBaseDN -DNSName $config.Domain.DNSName

Write-PowerADLog "Creating OU structure under base DN '$baseDN'"

foreach ($ouDef in $config.OrganizationalUnits) {
    $segments = $ouDef.Path -split '\\' | Where-Object { $_ -ne '' }
    $currentParentDN = $baseDN

    foreach ($segment in $segments) {
        $ouDN = "OU=$segment,$currentParentDN"
        $existing = Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ouDN'" -ErrorAction SilentlyContinue

        if ($existing) {
            Write-PowerADLog "OU already exists: $ouDN" -Level INFO
        }
        elseif ($PSCmdlet.ShouldProcess($ouDN, 'Create Organizational Unit')) {
            New-ADOrganizationalUnit -Name $segment -Path $currentParentDN -ProtectedFromAccidentalDeletion $ProtectFromDeletion
            Write-PowerADLog "Created OU: $ouDN" -Level SUCCESS
        }

        $currentParentDN = $ouDN
    }
}

Write-PowerADLog 'OU structure creation complete.' -Level SUCCESS
