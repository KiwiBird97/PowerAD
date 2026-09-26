<#
.SYNOPSIS
    Creates security/distribution groups defined in Config\Config.psd1.

.DESCRIPTION
    Reads the Groups array from the PowerAD configuration file and creates any
    group that does not already exist, placing it in its configured OU.
    Idempotent: safe to re-run at any time.

.PARAMETER ConfigPath
    Path to the PowerAD Config.psd1 file.

.EXAMPLE
    .\New-SecurityGroups.ps1
    Creates every group listed in Config.psd1.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot '..\Config\Config.psd1')
)

Import-Module (Join-Path $PSScriptRoot '..\Modules\PowerAD.Common.psm1') -Force
Assert-ModuleAvailable -Name ActiveDirectory
Import-Module ActiveDirectory -ErrorAction Stop

$config = Import-PowerADConfig -Path $ConfigPath
$baseDN = Get-PowerADBaseDN -DNSName $config.Domain.DNSName

foreach ($group in $config.Groups) {
    $ouDN = ConvertTo-PowerADOUDistinguishedName -RelativePath $group.OU -BaseDN $baseDN
    $existing = Get-ADGroup -Filter "Name -eq '$($group.Name)'" -ErrorAction SilentlyContinue

    if ($existing) {
        Write-PowerADLog "Group already exists: $($group.Name)" -Level INFO
        continue
    }

    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ouDN'" -ErrorAction SilentlyContinue)) {
        Write-PowerADLog "Target OU '$ouDN' does not exist yet. Run New-OUStructure.ps1 first. Skipping group '$($group.Name)'." -Level ERROR
        continue
    }

    if ($PSCmdlet.ShouldProcess($group.Name, "Create $($group.Category) group ($($group.Scope) scope) in $ouDN")) {
        New-ADGroup -Name $group.Name `
            -Path $ouDN `
            -GroupScope $group.Scope `
            -GroupCategory $group.Category `
            -Description $group.Description `
            -SamAccountName $group.Name

        Write-PowerADLog "Created group: $($group.Name) [$($group.Category)/$($group.Scope)] in $ouDN" -Level SUCCESS
    }
}

Write-PowerADLog 'Security group creation complete.' -Level SUCCESS
