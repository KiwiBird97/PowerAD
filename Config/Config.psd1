@{
    # ---------------------------------------------------------------------
    # PowerAD - Central Configuration
    # Edit this file to customize the environment before running any script.
    # ---------------------------------------------------------------------

    Domain = @{
        DNSName           = 'corp.powerad.local'
        NetBIOSName        = 'POWERAD'
        SafeModeAdminPwd    = 'ChangeMe!P@ssw0rd123'   # Used only during forest creation (DSRM password)
        DomainFunctionalLevel = 'WinThreshold'          # WinThreshold = Windows Server 2016+ compat level
        ForestFunctionalLevel = 'WinThreshold'
        DatabasePath        = 'C:\Windows\NTDS'
        LogPath             = 'C:\Windows\NTDS'
        SysvolPath          = 'C:\Windows\SYSVOL'
    }

    # Base distinguished name is derived automatically from Domain.DNSName at runtime.

    # Organizational Unit tree. 'Path' is relative to the domain root and uses
    # '\' to indicate nesting (e.g. 'Corp\IT' creates OU=IT,OU=Corp,<domain>).
    OrganizationalUnits = @(
        @{ Path = 'Corp' }
        @{ Path = 'Corp\HeadOffice' }
        @{ Path = 'Corp\Branches' }
        @{ Path = 'Departments' }
        @{ Path = 'Departments\IT' }
        @{ Path = 'Departments\HR' }
        @{ Path = 'Departments\Finance' }
        @{ Path = 'Departments\Sales' }
        @{ Path = 'Groups' }
        @{ Path = 'Groups\Security' }
        @{ Path = 'Groups\Distribution' }
        @{ Path = 'Servers' }
        @{ Path = 'Workstations' }
        @{ Path = 'ServiceAccounts' }
    )

    # Security / distribution groups.
    # Scope: DomainLocal | Global | Universal
    # Category: Security | Distribution
    Groups = @(
        @{ Name = 'SG-IT-Admins';        Scope = 'Global'; Category = 'Security'; OU = 'Groups\Security'; Description = 'IT department administrators' }
        @{ Name = 'SG-HR-Staff';         Scope = 'Global'; Category = 'Security'; OU = 'Groups\Security'; Description = 'Human Resources staff' }
        @{ Name = 'SG-Finance-Staff';    Scope = 'Global'; Category = 'Security'; OU = 'Groups\Security'; Description = 'Finance department staff' }
        @{ Name = 'SG-Sales-Staff';      Scope = 'Global'; Category = 'Security'; OU = 'Groups\Security'; Description = 'Sales department staff' }
        @{ Name = 'SG-All-Employees';    Scope = 'Global'; Category = 'Security'; OU = 'Groups\Security'; Description = 'All full-time employees' }
        @{ Name = 'SG-VPN-Users';        Scope = 'DomainLocal'; Category = 'Security'; OU = 'Groups\Security'; Description = 'Users allowed to connect via VPN' }
        @{ Name = 'SG-FileShare-ReadOnly';Scope = 'DomainLocal'; Category = 'Security'; OU = 'Groups\Security'; Description = 'Read-only access to shared file server' }
        @{ Name = 'SG-FileShare-ReadWrite';Scope = 'DomainLocal'; Category = 'Security'; OU = 'Groups\Security'; Description = 'Read/write access to shared file server' }
        @{ Name = 'SG-ServerAdmins';     Scope = 'DomainLocal'; Category = 'Security'; OU = 'Groups\Security'; Description = 'Local admin rights on member servers' }
        @{ Name = 'DL-Company-News';     Scope = 'Universal'; Category = 'Distribution'; OU = 'Groups\Distribution'; Description = 'Company-wide announcements' }
    )

    # Sample users. In practice, prefer importing from Users\Users.csv via New-ADUsers.ps1 -CsvPath.
    Users = @(
        @{ SamAccountName='jdoe';   GivenName='John';  Surname='Doe';   OU='Departments\IT';      Title='IT Administrator';  Department='IT';      Groups=@('SG-IT-Admins','SG-All-Employees','SG-ServerAdmins') }
        @{ SamAccountName='asmith'; GivenName='Alice'; Surname='Smith'; OU='Departments\HR';      Title='HR Manager';        Department='HR';      Groups=@('SG-HR-Staff','SG-All-Employees') }
        @{ SamAccountName='bwhite'; GivenName='Bob';   Surname='White'; OU='Departments\Finance';  Title='Financial Analyst'; Department='Finance'; Groups=@('SG-Finance-Staff','SG-All-Employees') }
        @{ SamAccountName='ctaylor';GivenName='Carol'; Surname='Taylor';OU='Departments\Sales';    Title='Sales Rep';         Department='Sales';   Groups=@('SG-Sales-Staff','SG-All-Employees') }
    )

    # Default password applied to newly created users (must satisfy the domain
    # password policy). Users are forced to change it at next logon.
    DefaultUserPassword = 'ChangeMe!P@ssw0rd123'

    # Group Policy Objects. 'SettingsScript' points to a script under GroupPolicy\Settings
    # that applies registry.pol / security settings via Set-GPRegistryValue and friends.
    GroupPolicies = @(
        @{ Name = 'GPO-Default-Domain-Password-Policy'; OU = $null;               Settings = 'PasswordPolicy' }
        @{ Name = 'GPO-Screen-Lock-Policy';              OU = 'Departments';       Settings = 'ScreenLock' }
        @{ Name = 'GPO-IT-Admin-Restrictions';           OU = 'Departments\IT';    Settings = 'ITAdmin' }
        @{ Name = 'GPO-Disable-USB-Storage';             OU = 'Workstations';      Settings = 'DisableUSB' }
        @{ Name = 'GPO-Map-Network-Drives';              OU = 'Departments';       Settings = 'DriveMaps' }
    )
}
