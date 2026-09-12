#Requires -Version 5.1
[CmdletBinding()]
# Both parameters arrive as plain strings because Terraform passes command-line
# arguments and this script cannot receive a SecureString directly (see the
# credential decision in PLAN.md). LocalAdminPassword is unused here and stays
# unused for the whole script - it only ever authenticates Terraform's own
# WinRM connection - but is declared anyway because every guest's Bootstrap
# script takes the same fixed parameters (AGENTS.md). DomainAdminPassword is
# unused only in this addressing phase; phase 2 (task 7) consumes it for the
# domain join, so its unused-parameter warning is not suppressed here.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'LocalAdminPassword', Justification = 'Terraform passes this as a plain command-line argument; see the credential decision in PLAN.md.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'DomainAdminPassword', Justification = 'Terraform passes this as a plain command-line argument; see the credential decision in PLAN.md.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'LocalAdminPassword', Justification = 'Every guest Bootstrap script takes the same fixed parameters; SRV01 does not need this one.')]
param(
    [string]$LocalAdminPassword,
    [string]$DomainAdminPassword
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path -Path $PSScriptRoot -ChildPath 'SILab.psm1') -Force

# docs/network-design.md - Servers VLAN (20).
$script:StaticAddress = '10.10.20.11'
$script:PrefixLength = 24
$script:DefaultGateway = '10.10.20.1'
# DC01 - already promoted by the time SRV01 runs, per runbook.md section 5's
# ordering (DC01's own apply is targeted and completed first).
$script:DnsServer = '10.10.20.10'

Start-SILabTranscript -ScriptName 'Bootstrap-SRV01'

try {
    if (-not (Test-SILabPhaseComplete -Number 1)) {
        $adapter = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
        if ($null -eq $adapter) {
            throw 'No active network adapter found.'
        }

        Set-NetIPInterface -InterfaceIndex $adapter.ifIndex -Dhcp Disabled
        Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
        New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $script:StaticAddress `
            -PrefixLength $script:PrefixLength -DefaultGateway $script:DefaultGateway | Out-Null
        Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $script:DnsServer

        # No rename and no reboot here. SRV01's hostname changes via
        # Add-Computer -NewName during the domain join (task 7) instead of a
        # separate Rename-Computer call, so the join credential is consumed in
        # the same invocation that receives it and never has to survive a
        # reboot. See the credential-ordering decision in PLAN.md.
        Set-SILabPhase -Number 1 -Name 'Addressing'
    }

    # Phase 2 (domain join) lands in task 7.
}
finally {
    Stop-SILabTranscript
}
