#Requires -Version 5.1
[CmdletBinding()]
# All three parameters arrive as plain strings because Terraform passes
# command-line arguments and this script cannot receive a SecureString
# directly (see the credential decision in PLAN.md). LocalAdminPassword is
# never used by DC01 - it only ever authenticates Terraform's own WinRM
# connection - but is declared anyway because every guest's Bootstrap script
# takes the same fixed parameters (AGENTS.md); there is no per-guest
# parameter list to trim it from. DomainAdminPassword IS used, despite DC01
# having no domain to join itself: a new forest's local Administrator account
# becomes its domain Administrator account, carrying over whatever password
# it had at promotion time, so phase 2 resets the local account to this
# password first - it is how SRV01 and CL01 (task 7) end up able to
# authenticate their own domain join as 'Administrator' with this same
# password. SafeModeAdminPassword does not reach Terraform's invocation of
# this script yet - task 11 wires it in.
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
# OPNsense's own resolver - DC01 is not authoritative for itself yet at this
# point (that only becomes true once promotion, task 4, has run), so this
# phase points DNS at something that already works instead.
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
        The GroupPolicy module's own cmdlets (Set-GPRegistryValue) only reach
        Administrative Template and Preference registry values. Account
        Policies and legacy audit categories live in a GPO's Security
        Settings instead (GptTmpl.inf on SYSVOL), which has no dedicated
        cmdlet - this writes that file directly and wires the Security
        Settings client-side extension onto the GPO's AD object, since a
        freshly created GPO has no extensions registered and would
        otherwise never have this file read at all.

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
    # GptTmpl.inf is traditionally saved as Unicode (UTF-16LE with a BOM) to
    # match its own [Unicode] header - unverified against a real GPMC-authored
    # file until the Milestone 8 proof run, the same kind of residual unknown
    # as the ForestMode/DomainMode value in the promotion phase.
    $unicodeEncoding = New-Object -TypeName System.Text.UnicodeEncoding -ArgumentList $false, $true
    [System.IO.File]::WriteAllText($templatePath, $body, $unicodeEncoding)

    # A brand-new GPO has no client-side extensions registered, so the policy
    # engine would never read GptTmpl.inf without this. versionNumber packs
    # (machineVersion << 16 | userVersion); this GPO carries only machine-side
    # settings and had no prior version, so 65536 (1 << 16) is exact, not
    # cumulative - a second call to this function on the same GPO would need
    # to read the existing value first, which none of this milestone's GPOs do.
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

        # docs/ad-design.md names the setting, not a specific image - this
        # project has no wallpaper asset of its own, so the stock Windows 11
        # default stands in.
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
        # Registered as a GP Preference (an arbitrary registry value, not an
        # Administrative Template policy) - there is no ADMX-backed policy for
        # the SMB1 server component, since it is normally toggled as a Windows
        # feature rather than a registry policy.
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
    # Phase 2's marker is written before Install-ADDSForest, which reboots on its
    # own. A failed promotion therefore leaves phase 2 marked complete, and the
    # resume walks straight into phase 3's site rename against a forest that does
    # not exist. DomainRole 4 and 5 are backup and primary domain controller.
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

        # Deliberately no Restart-Computer here. The recovery password phase 2
        # (promotion, below) needs arrives only in this same invocation, as a
        # command-line argument from Terraform's one-shot call - it cannot survive
        # a reboot without being written to disk, which the secrets decision in
        # PLAN.md forbids. Install-ADDSForest's own automatic reboot is what
        # finalizes this pending rename together with promotion, so there is only
        # ever one reboot on DC01 before the forest exists, not two. See the
        # credential-ordering decision in PLAN.md and the note on task 3 in
        # TASKS.md.
        Set-SILabPhase -Number 1 -Name 'Addressing'
    }

    if (-not (Test-SILabPhaseComplete -Number 2)) {
        Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools | Out-Null

        # A new forest's local Administrator account becomes the domain
        # Administrator account, carrying over whatever password it has right
        # now - so this is set to DomainAdminPassword *before* promoting,
        # rather than trying to change the domain account's password
        # afterwards (which would need this same parameter to survive
        # Install-ADDSForest's reboot, and nothing may persist a credential to
        # disk to make that survive). See task 7, which is what this feeds.
        $secureDomainAdminPassword = ConvertTo-SecureString -String $DomainAdminPassword -AsPlainText -Force
        Set-LocalUser -Name 'Administrator' -Password $secureDomainAdminPassword

        # Converted to a SecureString on the first line that touches it -
        # Terraform passes it as a command-line argument, so the script cannot
        # receive a SecureString directly. See the credential decision in
        # PLAN.md.
        $secureRecoveryPassword = ConvertTo-SecureString -String $SafeModeAdminPassword -AsPlainText -Force

        # Written before the call, not after: Install-ADDSForest reboots on its
        # own, so the resume must land on phase 3, not repeat this one.
        Set-SILabPhase -Number 2 -Name 'Promotion'
        Register-SILabResumeTask -TaskName $script:ResumeTaskName -ScriptPath $PSCommandPath

        # ForestMode/DomainMode 'Win2025' is this project's best-available
        # reading of docs/ad-design.md's "functional level 2025" requirement -
        # unconfirmed against a real Windows Server 2025 AD DS module until the
        # Milestone 8 proof run, the same kind of residual unknown Milestone 3
        # flagged for the Windows 11 image-index name.
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

        # This phase is the last one on DC01 that has any credential at all -
        # everything from here on runs as SYSTEM on a domain controller, which
        # already holds the rights the remaining phases need. See the
        # credential-ordering decision in PLAN.md.
    }

    if (-not (Test-SILabPhaseComplete -Number 3)) {
        # Resumed after promotion's reboot - the forest exists, so this and every
        # later phase needs no credential and no further reboot of its own.
        $existingSite = Get-ADReplicationSite -Filter "Name -eq '$script:SiteName'" -ErrorAction SilentlyContinue
        if ($null -eq $existingSite) {
            Get-ADReplicationSite -Filter "Name -eq 'Default-First-Site-Name'" |
                Rename-ADObject -NewName $script:SiteName
        }

        # DC01 is authoritative for its own domain now - point its DNS client at
        # itself instead of the bootstrap resolver from phase 1, and give the AD
        # DNS server role a forwarder for everything outside ad.silab.internal.
        $adapter = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
        Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $script:StaticAddress
        Set-DnsServerForwarder -IPAddress $script:DefaultGateway -PassThru | Out-Null

        Set-SILabPhase -Number 3 -Name 'SiteRename'
    }

    if (-not (Test-SILabPhaseComplete -Number 4)) {
        # Parents created before children - a retried phase may find some of
        # the tree already present, which New-SILabOrganizationalUnit's own
        # existence check makes safe to run again. The built-in Domain
        # Controllers OU is never touched - docs/ad-design.md keeps DC01 in it.
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
