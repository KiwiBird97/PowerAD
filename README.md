# PowerAD

**Power Active Directory** — a complete, PowerShell-driven Active Directory lab/environment builder for Windows Server 2022.

PowerAD automates the full lifecycle of standing up a small AD environment from a bare Windows Server 2022 box:

1. **Domain Controller deployment** — installs AD DS/DNS/GPMC features and promotes the server to the first DC in a new forest.
2. **Organizational Units (OUs)** — builds a configurable, nested OU hierarchy.
3. **Security groups** — creates domain-local/global/universal security & distribution groups.
4. **User provisioning** — creates users (from config or CSV) and assigns group memberships.
5. **Group Policy** — creates and links GPOs with baseline settings (screen lock, USB restrictions, password policy, etc.).

Everything is data-driven from a single [`Config\Config.psd1`](Config/Config.psd1) file, so you can re-target the whole environment (domain name, OUs, groups, users, GPOs) without touching script logic. Every script is **idempotent** — safe to re-run without duplicating objects.

## Requirements

- Windows Server 2022 (Datacenter/Standard) VM/machine, run **as Administrator**
- PowerShell 5.1+ (ships with Windows Server 2022)
- Local Administrator rights on the target machine
- Internet/offline media access for Windows feature installation

## Repository layout

```
PowerAD/
├── Config/
│   └── Config.psd1              # Central configuration: domain, OUs, groups, users, GPOs
├── Modules/
│   └── PowerAD.Common.psm1      # Shared helper functions (logging, DN conversion, guards)
├── DomainController/
│   └── Deploy-DomainController.ps1   # Installs AD DS + promotes new forest/domain
├── OUs/
│   └── New-OUStructure.ps1      # Creates the OU hierarchy
├── Groups/
│   └── New-SecurityGroups.ps1   # Creates security/distribution groups
├── Users/
│   ├── New-ADUsers.ps1          # Provisions users from Config.psd1 or CSV
│   └── Users.csv                # Sample bulk-user import template
├── GroupPolicy/
│   ├── Deploy-GroupPolicies.ps1 # Creates & links GPOs
│   └── Settings/
│       └── GPOSettings.psm1     # Per-GPO registry/security setting templates
├── Deploy-All.ps1               # Orchestrator: runs OUs -> Groups -> Users -> GPOs
└── .github/workflows/lint.yml   # PSScriptAnalyzer CI lint
```

## Quick start

### 1. Deploy the domain controller

On a fresh Windows Server 2022 machine, from an elevated PowerShell prompt:

```powershell
git clone https://github.com/KiwiBird97/PowerAD.git
cd PowerAD
notepad Config\Config.psd1   # review/edit domain name, NetBIOS name, DSRM password, etc.
.\DomainController\Deploy-DomainController.ps1
```

The server will reboot automatically to finish promotion. **Change the default passwords in `Config.psd1` before running in anything beyond a lab.**

### 2. Build out the rest of the environment

After the reboot, log back in as the Domain/Enterprise Administrator and run:

```powershell
cd C:\PowerAD   # wherever the repo lives
.\Deploy-All.ps1
```

This runs, in order:

```powershell
.\OUs\New-OUStructure.ps1
.\Groups\New-SecurityGroups.ps1
.\Users\New-ADUsers.ps1              # or: -CsvPath .\Users\Users.csv
.\GroupPolicy\Deploy-GroupPolicies.ps1
```

Each script can also be run independently, e.g. to add more users later:

```powershell
.\Users\New-ADUsers.ps1 -CsvPath .\Users\Users.csv
```

### 3. Customize

Edit `Config\Config.psd1` to add/remove:

- **OUs** — add entries to `OrganizationalUnits` using `Parent\Child` path notation.
- **Groups** — add entries to `Groups` with `Name`, `Scope` (`DomainLocal|Global|Universal`), `Category` (`Security|Distribution`), `OU`, and `Description`.
- **Users** — add entries to `Users`, or bulk-import via `Users\Users.csv` (columns: `SamAccountName,GivenName,Surname,OU,Title,Department,Password,Groups`; `Groups` is semicolon-delimited).
- **Group Policies** — add entries to `GroupPolicies` referencing a `Settings` template name implemented in `GroupPolicy\Settings\GPOSettings.psm1` (extend the module to add new templates).

## Safety notes

- All mutating scripts support `-WhatIf` (via `SupportsShouldProcess`) to preview changes before applying them, e.g. `.\OUs\New-OUStructure.ps1 -WhatIf`.
- Scripts check for existing objects before creating new ones, so `Deploy-All.ps1` can be safely re-run to reconcile drift or add new config entries.
- Default passwords in `Config.psd1` are placeholders — **rotate them** before using this outside an isolated lab/test environment.

## CI

A GitHub Actions workflow (`.github/workflows/lint.yml`) runs [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) against every script on push/PR to catch syntax and style issues early (it cannot execute AD cmdlets, since there's no live domain in CI).

## License

MIT — see [LICENSE](LICENSE).
