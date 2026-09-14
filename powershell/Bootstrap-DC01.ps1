#Requires -Version 5.1
[CmdletBinding()]
# All three arrive as plain strings, not SecureString - Terraform passes them as CLI args.
# LocalAdminPassword is unused here; every guest script takes the same fixed parameters.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'LocalAdminPassword', Justification = 'Terraform passes this as a plain command-line argument; see the credential decision in PLAN.md.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'DomainAdminPassword', Justification = 'Terraform passes this as a plain command-line argument; see the credential decision in PLAN.md.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'SafeModeAdminPassword', Justification = 'Terraform passes this as a plain command-line argument; see the credential decision in PLAN.md.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'These passwords arrive as plain command-line arguments and are converted to a SecureString on first use; see the credential decision in PLAN.md.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'LocalAdminPassword', Justification = 'Every guest Bootstrap script takes the same fixed parameters; DC01 does not need this one.')]
param(
    [string]$LocalAdminPassword,
    [string]$DomainAdminPassword,
    [string]$SafeModeAdminPassword
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path -Path $PSScriptRoot -ChildPath 'SILab.psm1') -Force

$script:ResumeTaskName = 'SILab-Resume-DC01'

# docs/network-design.md - Servers VLAN (20).
$script:StaticAddress = '10.10.20.10'
$script:PrefixLength = 24
$script:DefaultGateway = '10.10.20.1'
# OPNsense's own resolver - DC01 isn't authoritative for itself until after promotion.
$script:BootstrapDnsServer = '10.10.20.1'

# docs/ad-design.md.
$script:ForestDomainName = 'ad.silab.internal'
$script:DomainNetbiosName = 'SILAB'
$script:SiteName = 'SILAB-Lab'

function New-SILabOrganizationalUnit {
    <#
    .SYNOPSIS
        Creates an OU under the given parent, unless it already exists.

    .PARAMETER Name
        The OU's own name.

    .PARAMETER Path
        The parent container's distinguished name.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $existing = Get-ADOrganizationalUnit -Filter "Name -eq '$Name'" -SearchBase $Path -SearchScope OneLevel -ErrorAction SilentlyContinue
    if ($null -eq $existing -and $PSCmdlet.ShouldProcess("$Name,$Path", 'Create organizational unit')) {
        New-ADOrganizationalUnit -Name $Name -Path $Path | Out-Null
    }
}

function New-SILabGroup {
    <#
    .SYNOPSIS
        Creates a global security group, unless it already exists.

    .PARAMETER Name
        The group's name.

    .PARAMETER Path
        The container to create it in.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $existing = Get-ADGroup -Filter "Name -eq '$Name'" -ErrorAction SilentlyContinue
    if ($null -eq $existing -and $PSCmdlet.ShouldProcess($Name, 'Create AD group')) {
        New-ADGroup -Name $Name -Path $Path -GroupScope Global -GroupCategory Security | Out-Null
    }
}

function Set-SILabSecurityTemplate {
    <#
    .SYNOPSIS
        Writes Account Policy / Audit Policy settings into a GPO's GptTmpl.inf.

    .DESCRIPTION
        Set-GPRegistryValue only reaches Administrative Template and Preference values.
        Account Policies and audit categories live in GptTmpl.inf on SYSVOL instead, which
        has no dedicated cmdlet - this writes it directly and wires the Security Settings
        client-side extension onto the GPO's AD object, since a fresh GPO has none registered.

    .PARAMETER Gpo
        The GPO object from New-GPO/Get-GPO to write the template into.

    .PARAMETER IniContent
        The GptTmpl.inf section(s) to write, e.g. "[System Access]`nMinimumPasswordLength = 12".
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        $Gpo,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$IniContent
    )

    $domainDnsName = (Get-ADDomain).DNSRoot
    $policyDir = "\\$domainDnsName\SysVol\$domainDnsName\Policies\{$($Gpo.Id)}\Machine\Microsoft\Windows NT\SecEdit"
    $templatePath = Join-Path -Path $policyDir -ChildPath 'GptTmpl.inf'

    if (-not $PSCmdlet.ShouldProcess($templatePath, 'Write security template')) {
        return
    }

    if (-not (Test-Path -LiteralPath $policyDir)) {
        $null = New-Item -Path $policyDir -ItemType Directory -Force
    }

    $body = "[Unicode]`r`nUnicode=yes`r`n[Version]`r`nsignature=`"`$CHICAGO`$`"`r`nRevision=1`r`n$IniContent`r`n"
    # UTF-16LE with BOM to match the [Unicode] header; unverified against a real GPMC-authored file.
    $unicodeEncoding = New-Object -TypeName System.Text.UnicodeEncoding -ArgumentList $false, $true
    [System.IO.File]::WriteAllText($templatePath, $body, $unicodeEncoding)

    # versionNumber packs (machineVersion << 16 | userVersion); 65536 is exact since this GPO is new -
    # a second call would need to read the existing value first.
    Set-ADObject -Identity $Gpo.Path -Replace @{
        gPCMachineExtensionNames = '[{827D319E-6EAC-11D2-A4EA-00C04F79F83A}{803E14A0-B4FB-11D0-A0D0-00A0C90F574B}]'
        versionNumber            = 65536
    }

    $gptIniPath = "\\$domainDnsName\SysVol\$domainDnsName\Policies\{$($Gpo.Id)}\GPT.INI"
    (Get-Content -LiteralPath $gptIniPath -Raw) -replace 'Version=\d+', 'Version=65536' |
        Set-Content -LiteralPath $gptIniPath -Encoding ASCII
}

function New-SILabPasswordPolicyGPO {
    <#
    .SYNOPSIS
        Creates and links the Domain Password & Lockout Policy GPO.

    .DESCRIPTION
        Settings come from docs/ad-design.md's GPO table and nowhere else.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $gpoName = 'Domain Password & Lockout Policy'
    $gpo = Get-GPO -Name $gpoName -ErrorAction SilentlyContinue
    if ($null -eq $gpo -and $PSCmdlet.ShouldProcess($gpoName, 'Create GPO')) {
        $gpo = New-GPO -Name $gpoName
        Set-SILabSecurityTemplate -Gpo $gpo -IniContent "[System Access]`r`nMinimumPasswordLength = 12`r`nPasswordComplexity = 1`r`nLockoutBadCount = 5"
    }

    if ($null -ne $gpo) {
        $domainDN = (Get-ADDomain).DistinguishedName
        $alreadyLinked = (Get-GPInheritance -Target $domainDN).GpoLinks | Where-Object { $_.GpoId -eq $gpo.Id }
        if ($null -eq $alreadyLinked -and $PSCmdlet.ShouldProcess($domainDN, "Link GPO '$gpoName'")) {
            New-GPLink -Guid $gpo.Id -Target $domainDN | Out-Null
        }
    }
}

function New-SILabWorkstationBaselineGPO {
    <#
    .SYNOPSIS
        Creates and links the Workstation Baseline GPO.

    .DESCRIPTION
        Settings come from docs/ad-design.md's GPO table and nowhere else. The
        logon banner is the visible proof point this milestone is checked
        against - see Test-SILab.ps1 (task 8).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $gpoName = 'Workstation Baseline'
    $gpo = Get-GPO -Name $gpoName -ErrorAction SilentlyContinue
    if ($null -eq $gpo -and $PSCmdlet.ShouldProcess($gpoName, 'Create GPO')) {
        $gpo = New-GPO -Name $gpoName

        Set-GPRegistryValue -Guid $gpo.Id -Key 'HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System' `
            -ValueName 'LegalNoticeCaption' -Type String -Value 'SILAB' | Out-Null
        Set-GPRegistryValue -Guid $gpo.Id -Key 'HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System' `
            -ValueName 'LegalNoticeText' -Type String -Value 'Authorized use only.' | Out-Null

        # docs/ad-design.md names the setting, not a specific image; the stock Windows 11 default stands in.
        Set-GPRegistryValue -Guid $gpo.Id -Key 'HKCU\Software\Policies\Microsoft\Windows\Desktop' `
            -ValueName 'Wallpaper' -Type String -Value 'C:\Windows\Web\Wallpaper\Windows\img0.jpg' | Out-Null
        Set-GPRegistryValue -Guid $gpo.Id -Key 'HKCU\Software\Policies\Microsoft\Windows\Desktop' `
            -ValueName 'WallpaperStyle' -Type String -Value '10' | Out-Null

        Set-GPRegistryValue -Guid $gpo.Id -Key 'HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection' `
            -ValueName 'DisableRealtimeMonitoring' -Type DWord -Value 0 | Out-Null
    }

    if ($null -ne $gpo) {
        $targetOU = "OU=Workstations,OU=Computers,OU=SILAB,$((Get-ADDomain).DistinguishedName)"
        $alreadyLinked = (Get-GPInheritance -Target $targetOU).GpoLinks | Where-Object { $_.GpoId -eq $gpo.Id }
        if ($null -eq $alreadyLinked -and $PSCmdlet.ShouldProcess($targetOU, "Link GPO '$gpoName'")) {
            New-GPLink -Guid $gpo.Id -Target $targetOU | Out-Null
        }
    }
}

function New-SILabServerBaselineGPO {
    <#
    .SYNOPSIS
        Creates and links the Server Baseline GPO.

    .DESCRIPTION
        Settings come from docs/ad-design.md's GPO table and nowhere else.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $gpoName = 'Server Baseline'
    $gpo = Get-GPO -Name $gpoName -ErrorAction SilentlyContinue
    if ($null -eq $gpo -and $PSCmdlet.ShouldProcess($gpoName, 'Create GPO')) {
        $gpo = New-GPO -Name $gpoName

        Set-GPRegistryValue -Guid $gpo.Id -Key 'HKLM\Software\Policies\Microsoft\WindowsFirewall\DomainProfile' `
            -ValueName 'EnableFirewall' -Type DWord -Value 1 | Out-Null
        # GP Preference, not an ADMX policy - SMB1 is normally toggled as a Windows feature, not a registry value.
        Set-GPRegistryValue -Guid $gpo.Id -Key 'HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' `
            -ValueName 'SMB1' -Type DWord -Value 0 | Out-Null

        Set-SILabSecurityTemplate -Gpo $gpo -IniContent "[Event Audit]`r`nAuditAccountLogon = 3`r`nAuditLogonEvents = 3`r`nAuditPolicyChange = 3`r`nAuditPrivilegeUse = 3"
    }

    if ($null -ne $gpo) {
        $targetOU = "OU=Servers,OU=Computers,OU=SILAB,$((Get-ADDomain).DistinguishedName)"
        $alreadyLinked = (Get-GPInheritance -Target $targetOU).GpoLinks | Where-Object { $_.GpoId -eq $gpo.Id }
        if ($null -eq $alreadyLinked -and $PSCmdlet.ShouldProcess($targetOU, "Link GPO '$gpoName'")) {
            New-GPLink -Guid $gpo.Id -Target $targetOU | Out-Null
        }
    }
}

Start-SILabTranscript -ScriptName 'Bootstrap-DC01'

try {
    # DomainRole 4/5 = backup/primary domain controller.
    Assert-SILabPhaseEffect -Number 2 -Name 'Promotion' -Test {
        (Get-CimInstance -ClassName Win32_ComputerSystem).DomainRole -in @(4, 5)
    }

    if (-not (Test-SILabPhaseComplete -Number 1)) {
        if ((Get-CimInstance -ClassName Win32_ComputerSystem).Name -ne 'DC01') {
            Rename-Computer -NewName 'DC01' -Force
        }

        $adapter = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
        if ($null -eq $adapter) {
            throw 'No active network adapter found.'
        }

        Set-NetIPInterface -InterfaceIndex $adapter.ifIndex -Dhcp Disabled
        Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
        New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $script:StaticAddress `
            -PrefixLength $script:PrefixLength -DefaultGateway $script:DefaultGateway | Out-Null
        Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $script:BootstrapDnsServer

        # No Restart-Computer here - Install-ADDSForest's own reboot finalizes this pending rename
        # together with promotion, so DC01 reboots once, not twice.
        Set-SILabPhase -Number 1 -Name 'Addressing'
    }

    if (-not (Test-SILabPhaseComplete -Number 2)) {
        Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools | Out-Null

        # The local Administrator becomes the domain Administrator on promotion, carrying over
        # its current password - set before promoting, not after.
        $secureDomainAdminPassword = ConvertTo-SecureString -String $DomainAdminPassword -AsPlainText -Force
        Set-LocalUser -Name 'Administrator' -Password $secureDomainAdminPassword

        $secureRecoveryPassword = ConvertTo-SecureString -String $SafeModeAdminPassword -AsPlainText -Force

        # Written before the call - Install-ADDSForest reboots on its own, so resume must land on phase 3.
        Set-SILabPhase -Number 2 -Name 'Promotion'
        Register-SILabResumeTask -TaskName $script:ResumeTaskName -ScriptPath $PSCommandPath

        # 'Win2025' is this project's best reading of docs/ad-design.md's "functional level 2025";
        # unconfirmed against a real Windows Server 2025 AD DS module.
        Install-ADDSForest `
            -DomainName $script:ForestDomainName `
            -DomainNetbiosName $script:DomainNetbiosName `
            -ForestMode 'Win2025' `
            -DomainMode 'Win2025' `
            -SafeModeAdministratorPassword $secureRecoveryPassword `
            -InstallDns `
            -NoRebootOnCompletion:$false `
            -Force `
            -Confirm:$false

        # Last phase on DC01 with any credential - everything after runs as SYSTEM on a DC.
    }

    if (-not (Test-SILabPhaseComplete -Number 3)) {
        $existingSite = Get-ADReplicationSite -Filter "Name -eq '$script:SiteName'" -ErrorAction SilentlyContinue
        if ($null -eq $existingSite) {
            Get-ADReplicationSite -Filter "Name -eq 'Default-First-Site-Name'" |
                Rename-ADObject -NewName $script:SiteName
        }

        # Point DNS at itself now instead of phase 1's bootstrap resolver, and forward everything else.
        $adapter = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
        Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $script:StaticAddress
        Set-DnsServerForwarder -IPAddress $script:DefaultGateway -PassThru | Out-Null

        Set-SILabPhase -Number 3 -Name 'SiteRename'
    }

    if (-not (Test-SILabPhaseComplete -Number 4)) {
        # Parents created before children; New-SILabOrganizationalUnit's existence check makes a retry safe.
        $domainDN = (Get-ADDomain).DistinguishedName

        New-SILabOrganizationalUnit -Name 'SILAB' -Path $domainDN
        $silabOU = "OU=SILAB,$domainDN"

        New-SILabOrganizationalUnit -Name 'Computers' -Path $silabOU
        $computersOU = "OU=Computers,$silabOU"

        New-SILabOrganizationalUnit -Name 'Servers' -Path $computersOU
        New-SILabOrganizationalUnit -Name 'Workstations' -Path $computersOU
        New-SILabOrganizationalUnit -Name 'Users' -Path $silabOU
        New-SILabOrganizationalUnit -Name 'Groups' -Path $silabOU
        New-SILabOrganizationalUnit -Name 'Service Accounts' -Path $silabOU

        $groupsOU = "OU=Groups,$silabOU"
        New-SILabGroup -Name 'SILAB-Admins' -Path $groupsOU
        New-SILabGroup -Name 'SILAB-Helpdesk' -Path $groupsOU

        Set-SILabPhase -Number 4 -Name 'OUsAndGroups'
    }

    if (-not (Test-SILabPhaseComplete -Number 5)) {
        Install-WindowsFeature -Name GPMC | Out-Null

        New-SILabPasswordPolicyGPO
        New-SILabWorkstationBaselineGPO
        New-SILabServerBaselineGPO

        Set-SILabPhase -Number 5 -Name 'BaselineGPOs'

        # Last phase on DC01 - nothing left for the resume task to trigger.
        Unregister-SILabResumeTask -TaskName $script:ResumeTaskName
    }
}
finally {
    Stop-SILabTranscript
}
