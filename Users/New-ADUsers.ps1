<#
.SYNOPSIS
    Provisions Active Directory user accounts, either from Config\Config.psd1
    or from a CSV file (Users\Users.csv).

.DESCRIPTION
    Creates each user (if not already present), sets a default/temporary
    password, forces a password change at next logon, and adds the user to
    the security groups listed for them. Idempotent: safe to re-run.

.PARAMETER ConfigPath
    Path to the PowerAD Config.psd1 file. Used for domain info and the
    default password, and as the user source when -CsvPath is not supplied.

.PARAMETER CsvPath
    Optional path to a CSV file (columns: SamAccountName, GivenName, Surname,
    OU, Title, Department, Password, Groups [semicolon-delimited]) to use as
    the user source instead of Config.psd1. If a row's Password column is
    blank, the config's DefaultUserPassword is used.

.EXAMPLE
    .\New-ADUsers.ps1
    Creates users defined in Config.psd1.

.EXAMPLE
    .\New-ADUsers.ps1 -CsvPath .\Users.csv
    Creates users from the bundled CSV template.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot '..\Config\Config.psd1'),
    [string]$CsvPath
)

Import-Module (Join-Path $PSScriptRoot '..\Modules\PowerAD.Common.psm1') -Force
Assert-ModuleAvailable -Name ActiveDirectory
Import-Module ActiveDirectory -ErrorAction Stop

$config = Import-PowerADConfig -Path $ConfigPath
$baseDN = Get-PowerADBaseDN -DNSName $config.Domain.DNSName
$defaultPassword = $config.DefaultUserPassword

if ($CsvPath) {
    if (-not (Test-Path $CsvPath)) { throw "CSV file not found: $CsvPath" }
    Write-PowerADLog "Loading users from CSV: $CsvPath"
    $users = Import-Csv -Path $CsvPath | ForEach-Object {
        [PSCustomObject]@{
            SamAccountName = $_.SamAccountName
            GivenName      = $_.GivenName
            Surname        = $_.Surname
            OU             = $_.OU
            Title          = $_.Title
            Department     = $_.Department
            Password       = if ([string]::IsNullOrWhiteSpace($_.Password)) { $defaultPassword } else { $_.Password }
            Groups         = if ($_.Groups) { $_.Groups -split ';' } else { @() }
        }
    }
}
else {
    Write-PowerADLog 'Loading users from Config.psd1'
    $users = $config.Users | ForEach-Object {
        [PSCustomObject]@{
            SamAccountName = $_.SamAccountName
            GivenName      = $_.GivenName
            Surname        = $_.Surname
            OU             = $_.OU
            Title          = $_.Title
            Department     = $_.Department
            Password       = $defaultPassword
            Groups         = $_.Groups
        }
    }
}

foreach ($user in $users) {
    $ouDN = ConvertTo-PowerADOUDistinguishedName -RelativePath $user.OU -BaseDN $baseDN
    $upn = "$($user.SamAccountName)@$($config.Domain.DNSName)"
    $displayName = "$($user.GivenName) $($user.Surname)"

    $existing = Get-ADUser -Filter "SamAccountName -eq '$($user.SamAccountName)'" -ErrorAction SilentlyContinue

    if ($existing) {
        Write-PowerADLog "User already exists: $($user.SamAccountName)" -Level INFO
    }
    else {
        if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ouDN'" -ErrorAction SilentlyContinue)) {
            Write-PowerADLog "Target OU '$ouDN' does not exist. Run New-OUStructure.ps1 first. Skipping user '$($user.SamAccountName)'." -Level ERROR
            continue
        }

        if ($PSCmdlet.ShouldProcess($user.SamAccountName, "Create AD user in $ouDN")) {
            $securePwd = ConvertTo-SecureString $user.Password -AsPlainText -Force
            New-ADUser -Name $displayName `
                -GivenName $user.GivenName `
                -Surname $user.Surname `
                -SamAccountName $user.SamAccountName `
                -UserPrincipalName $upn `
                -Path $ouDN `
                -Title $user.Title `
                -Department $user.Department `
                -AccountPassword $securePwd `
                -ChangePasswordAtLogon $true `
                -Enabled $true

            Write-PowerADLog "Created user: $($user.SamAccountName) ($displayName) in $ouDN" -Level SUCCESS
        }
    }

    foreach ($groupName in $user.Groups) {
        if (-not $groupName) { continue }
        $group = Get-ADGroup -Filter "Name -eq '$groupName'" -ErrorAction SilentlyContinue
        if (-not $group) {
            Write-PowerADLog "Group '$groupName' not found; run New-SecurityGroups.ps1 first. Skipping membership for '$($user.SamAccountName)'." -Level ERROR
            continue
        }
        $isMember = Get-ADGroupMember -Identity $group | Where-Object { $_.SamAccountName -eq $user.SamAccountName }
        if ($isMember) {
            Write-PowerADLog "$($user.SamAccountName) already a member of $groupName" -Level INFO
        }
        elseif ($PSCmdlet.ShouldProcess("$($user.SamAccountName) -> $groupName", 'Add-ADGroupMember')) {
            Add-ADGroupMember -Identity $group -Members $user.SamAccountName
            Write-PowerADLog "Added $($user.SamAccountName) to group $groupName" -Level SUCCESS
        }
    }
}

Write-PowerADLog 'User provisioning complete.' -Level SUCCESS
