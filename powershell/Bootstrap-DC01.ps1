#Requires -Version 5.1
[CmdletBinding()]
# All three parameters arrive as plain strings because Terraform passes
# command-line arguments and this script cannot receive a SecureString
# directly (see the credential decision in PLAN.md). LocalAdminPassword and
# DomainAdminPassword are never used by DC01 - the local admin password only
# ever authenticates Terraform's own WinRM connection, and DC01 has no domain
# to join - but are declared anyway because every guest's Bootstrap script
# takes the same fixed parameters (AGENTS.md); there is no per-guest
# parameter list to trim these from. SafeModeAdminPassword does not reach
# Terraform's invocation of this script yet - task 11 wires it in.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'LocalAdminPassword', Justification = 'Terraform passes this as a plain command-line argument; see the credential decision in PLAN.md.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'DomainAdminPassword', Justification = 'Terraform passes this as a plain command-line argument; see the credential decision in PLAN.md.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'SafeModeAdminPassword', Justification = 'Terraform passes this as a plain command-line argument; see the credential decision in PLAN.md.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'The recovery password arrives as a plain command-line argument and is converted to a SecureString on first use; see the credential decision in PLAN.md.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'LocalAdminPassword', Justification = 'Every guest Bootstrap script takes the same fixed parameters; DC01 does not need this one.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'DomainAdminPassword', Justification = 'Every guest Bootstrap script takes the same fixed parameters; DC01 does not need this one.')]
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

Start-SILabTranscript -ScriptName 'Bootstrap-DC01'

try {
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

    # Phase 4 (OU tree and groups) lands in task 5.
}
finally {
    Stop-SILabTranscript
}
