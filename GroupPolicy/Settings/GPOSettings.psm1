<#
.SYNOPSIS
    Defines the registry/security settings applied to each named GPO template
    used by Deploy-GroupPolicies.ps1.

.DESCRIPTION
    Each function below takes a GPO name and applies a specific set of
    settings to it via Set-GPRegistryValue. Add new templates here and
    reference them from Config.psd1's GroupPolicies[].Settings value.
#>

function Set-PasswordPolicyGPOSettings {
    param([Parameter(Mandatory)] [string]$GpoName)

    Set-GPRegistryValue -Name $GpoName -Key 'HKLM\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters' `
        -ValueName 'RefusePasswordChange' -Type DWord -Value 0 | Out-Null

    # Fine-grained password settings are normally configured via Default Domain
    # Policy security settings (Account Policies) rather than registry.pol.
    # Apply account lockout / complexity requirements using secedit-based export
    # if stricter control than the domain default is required.
    Write-PowerADLog "Applied password policy baseline registry values to '$GpoName'." -Level INFO
}

function Set-ScreenLockGPOSettings {
    param([Parameter(Mandatory)] [string]$GpoName)

    Set-GPRegistryValue -Name $GpoName -Key 'HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop' `
        -ValueName 'ScreenSaveActive' -Type String -Value '1' | Out-Null
    Set-GPRegistryValue -Name $GpoName -Key 'HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop' `
        -ValueName 'ScreenSaverIsSecure' -Type String -Value '1' | Out-Null
    Set-GPRegistryValue -Name $GpoName -Key 'HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop' `
        -ValueName 'ScreenSaveTimeOut' -Type String -Value '600' | Out-Null

    Write-PowerADLog "Applied 10-minute secure screen lock settings to '$GpoName'." -Level INFO
}

function Set-ITAdminGPOSettings {
    param([Parameter(Mandatory)] [string]$GpoName)

    Set-GPRegistryValue -Name $GpoName -Key 'HKLM\Software\Policies\Microsoft\Windows\System' `
        -ValueName 'EnableSmartScreen' -Type DWord -Value 1 | Out-Null
    Set-GPRegistryValue -Name $GpoName -Key 'HKLM\Software\Policies\Microsoft\Windows Defender' `
        -ValueName 'DisableAntiSpyware' -Type DWord -Value 0 | Out-Null

    Write-PowerADLog "Applied IT administrator security baseline to '$GpoName'." -Level INFO
}

function Set-DisableUSBGPOSettings {
    param([Parameter(Mandatory)] [string]$GpoName)

    Set-GPRegistryValue -Name $GpoName -Key 'HKLM\System\CurrentControlSet\Services\USBSTOR' `
        -ValueName 'Start' -Type DWord -Value 4 | Out-Null

    Write-PowerADLog "Applied USB mass-storage disable setting to '$GpoName'." -Level INFO
}

function Set-DriveMapsGPOSettings {
    param([Parameter(Mandatory)] [string]$GpoName)

    # Drive mapping preferences require GPMC's Group Policy Preferences XML
    # (Drives.xml under the GPO's user policy folder). This placeholder logs
    # intent; customize with your file server UNC paths as needed.
    Write-PowerADLog "GPO '$GpoName' reserved for drive-mapping preferences. Add Drives.xml preference items as needed." -Level WARN
}

Export-ModuleMember -Function *
