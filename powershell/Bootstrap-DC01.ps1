#Requires -Version 5.1
[CmdletBinding()]
# Both parameters arrive as plain strings because Terraform passes command-line
# arguments and this script cannot receive a SecureString directly (see the
# credential decision in PLAN.md) - and neither is actually used by DC01: the
# local admin password only ever authenticates Terraform's own WinRM
# connection, and DC01 has no domain to join. Declared anyway because every
# guest's Bootstrap script takes the same fixed parameters (AGENTS.md) - there
# is no per-guest parameter list to trim these from.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'LocalAdminPassword', Justification = 'Terraform passes this as a plain command-line argument; see the credential decision in PLAN.md.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'DomainAdminPassword', Justification = 'Terraform passes this as a plain command-line argument; see the credential decision in PLAN.md.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'LocalAdminPassword', Justification = 'Every guest Bootstrap script takes the same fixed parameters; DC01 does not need this one.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'DomainAdminPassword', Justification = 'Every guest Bootstrap script takes the same fixed parameters; DC01 does not need this one.')]
param(
    [string]$LocalAdminPassword,
    [string]$DomainAdminPassword
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path -Path $PSScriptRoot -ChildPath 'SILab.psm1') -Force

# docs/network-design.md - Servers VLAN (20).
$script:StaticAddress = '10.10.20.10'
$script:PrefixLength = 24
$script:DefaultGateway = '10.10.20.1'
# OPNsense's own resolver - DC01 is not authoritative for itself yet at this
# point (that only becomes true once promotion, task 4, has run), so this
# phase points DNS at something that already works instead.
$script:BootstrapDnsServer = '10.10.20.1'

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
        # (promotion, task 4) needs arrives only in this same invocation, as a
        # command-line argument from Terraform's one-shot call - it cannot survive
        # a reboot without being written to disk, which the secrets decision in
        # PLAN.md forbids. Install-ADDSForest's own automatic reboot is what
        # finalizes this pending rename together with promotion, so there is only
        # ever one reboot on DC01 before the forest exists, not two. See the
        # credential-ordering decision in PLAN.md and the note on this task in
        # TASKS.md.
        Set-SILabPhase -Number 1 -Name 'Addressing'
    }

    # Phase 2 (AD DS promotion) lands in task 4.
}
finally {
    Stop-SILabTranscript
}
