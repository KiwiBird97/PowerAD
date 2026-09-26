<#
.SYNOPSIS
    Shared helper functions used across the PowerAD script suite.
#>

function Write-PowerADLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Message,
        [ValidateSet('INFO','WARN','ERROR','SUCCESS')] [string]$Level = 'INFO'
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = switch ($Level) {
        'WARN'    { 'Yellow' }
        'ERROR'   { 'Red' }
        'SUCCESS' { 'Green' }
        default   { 'Cyan' }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Import-PowerADConfig {
    [CmdletBinding()]
    param(
        [string]$Path = (Join-Path $PSScriptRoot '..\Config\Config.psd1')
    )
    if (-not (Test-Path $Path)) {
        throw "PowerAD configuration file not found at '$Path'."
    }
    Import-PowerShellDataFile -Path $Path
}

function Get-PowerADBaseDN {
    <#
    .SYNOPSIS
        Converts a DNS domain name (e.g. corp.powerad.local) to a Distinguished Name
        (e.g. DC=corp,DC=powerad,DC=local).
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string]$DNSName)
    ($DNSName -split '\.' | ForEach-Object { "DC=$_" }) -join ','
}

function ConvertTo-PowerADOUDistinguishedName {
    <#
    .SYNOPSIS
        Converts a slash-delimited relative OU path (e.g. 'Departments\IT') into a
        full Distinguished Name, innermost OU first.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$RelativePath,
        [Parameter(Mandatory)] [string]$BaseDN
    )
    $segments = $RelativePath -split '\\' | Where-Object { $_ -ne '' }
    $ouParts = ($segments | ForEach-Object { "OU=$_" })
    [array]::Reverse($ouParts)
    (($ouParts -join ',') + ',' + $BaseDN)
}

function Assert-RunAsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'This script must be run from an elevated (Administrator) PowerShell session.'
    }
}

function Assert-ModuleAvailable {
    param([Parameter(Mandatory)] [string]$Name)
    if (-not (Get-Module -ListAvailable -Name $Name)) {
        throw "Required module '$Name' is not installed on this machine. Install the matching Windows feature/RSAT tools first."
    }
}

Export-ModuleMember -Function *
