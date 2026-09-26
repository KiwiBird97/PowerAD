<#
.SYNOPSIS
    Creates and links Group Policy Objects (GPOs) defined in Config\Config.psd1.

.DESCRIPTION
    For each entry in Config.psd1's GroupPolicies array, creates the GPO if it
    doesn't already exist, applies its named settings template (see
    GroupPolicy\Settings\GPOSettings.psm1), and links it to the configured OU
    (or leaves it unlinked if OU is $null, e.g. for a domain-level policy you
    intend to link manually to the Default Domain Policy location).
    Idempotent: safe to re-run at any time.

.PARAMETER ConfigPath
    Path to the PowerAD Config.psd1 file.

.EXAMPLE
    .\Deploy-GroupPolicies.ps1
    Creates and links every GPO listed in Config.psd1.

.NOTES
    Requires the Group Policy Management Console (GPMC) feature and the
    GroupPolicy PowerShell module, both installed by Deploy-DomainController.ps1.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot '..\Config\Config.psd1')
)

Import-Module (Join-Path $PSScriptRoot '..\Modules\PowerAD.Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Settings\GPOSettings.psm1') -Force
Assert-ModuleAvailable -Name GroupPolicy
Import-Module GroupPolicy -ErrorAction Stop
Import-Module ActiveDirectory -ErrorAction Stop

$config = Import-PowerADConfig -Path $ConfigPath
$baseDN = Get-PowerADBaseDN -DNSName $config.Domain.DNSName

$settingsHandlers = @{
    PasswordPolicy = 'Set-PasswordPolicyGPOSettings'
    ScreenLock     = 'Set-ScreenLockGPOSettings'
    ITAdmin        = 'Set-ITAdminGPOSettings'
    DisableUSB     = 'Set-DisableUSBGPOSettings'
    DriveMaps      = 'Set-DriveMapsGPOSettings'
}

foreach ($gpoDef in $config.GroupPolicies) {
    $gpoName = $gpoDef.Name
    $existing = Get-GPO -Name $gpoName -ErrorAction SilentlyContinue

    if ($existing) {
        Write-PowerADLog "GPO already exists: $gpoName" -Level INFO
    }
    elseif ($PSCmdlet.ShouldProcess($gpoName, 'Create Group Policy Object')) {
        $existing = New-GPO -Name $gpoName -Comment "Managed by PowerAD (Settings: $($gpoDef.Settings))"
        Write-PowerADLog "Created GPO: $gpoName" -Level SUCCESS
    }

    # Apply settings template
    $handler = $settingsHandlers[$gpoDef.Settings]
    if ($handler -and (Get-Command $handler -ErrorAction SilentlyContinue)) {
        & $handler -GpoName $gpoName
    }
    else {
        Write-PowerADLog "No settings handler found for template '$($gpoDef.Settings)' on GPO '$gpoName'." -Level WARN
    }

    # Link to target OU (or domain root when OU is $null)
    if ($gpoDef.OU) {
        $ouDN = ConvertTo-PowerADOUDistinguishedName -RelativePath $gpoDef.OU -BaseDN $baseDN
        if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ouDN'" -ErrorAction SilentlyContinue)) {
            Write-PowerADLog "Target OU '$ouDN' does not exist. Run New-OUStructure.ps1 first. Skipping link for '$gpoName'." -Level ERROR
            continue
        }
        $targetDN = $ouDN
    }
    else {
        $targetDN = $baseDN
    }

    $alreadyLinked = (Get-GPInheritance -Target $targetDN).GpoLinks | Where-Object { $_.DisplayName -eq $gpoName }
    if ($alreadyLinked) {
        Write-PowerADLog "GPO '$gpoName' already linked to $targetDN" -Level INFO
    }
    elseif ($PSCmdlet.ShouldProcess("$gpoName -> $targetDN", 'New-GPLink')) {
        New-GPLink -Name $gpoName -Target $targetDN -LinkEnabled Yes | Out-Null
        Write-PowerADLog "Linked GPO '$gpoName' to $targetDN" -Level SUCCESS
    }
}

Write-PowerADLog 'Group Policy deployment complete.' -Level SUCCESS
