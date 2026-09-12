#Requires -Version 5.1
[CmdletBinding()]
# Both arrive as plain strings - Terraform passes CLI args, no SecureString
# (PLAN.md credential decision). LocalAdminPassword is unused here (every
# guest's script takes the same fixed parameters, AGENTS.md); DomainAdminPassword
# is used by phase 2 below.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'LocalAdminPassword', Justification = 'Terraform passes this as a plain command-line argument; see the credential decision in PLAN.md.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'DomainAdminPassword', Justification = 'Terraform passes this as a plain command-line argument; see the credential decision in PLAN.md.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'The domain admin password arrives as a plain command-line argument and is converted to a SecureString on first use; see the credential decision in PLAN.md.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'LocalAdminPassword', Justification = 'Every guest Bootstrap script takes the same fixed parameters; SRV01 does not need this one.')]
param(
    [string]$LocalAdminPassword,
    [string]$DomainAdminPassword
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path -Path $PSScriptRoot -ChildPath 'SILab.psm1') -Force

$script:ResumeTaskName = 'SILab-Resume-SRV01'

# docs/network-design.md - Servers VLAN (20).
$script:StaticAddress = '10.10.20.11'
$script:PrefixLength = 24
$script:DefaultGateway = '10.10.20.1'
# DC01 - already promoted by the time SRV01 runs (runbook.md section 5 ordering).
$script:DnsServer = '10.10.20.10'

# docs/ad-design.md.
$script:ForestDomainName = 'ad.silab.internal'
$script:TargetOU = 'OU=Servers,OU=Computers,OU=SILAB,DC=ad,DC=silab,DC=internal'

function Wait-SILabDomainController {
    <#
    .SYNOPSIS
        Blocks until a domain controller answers on LDAP.

    .DESCRIPTION
        A member booting before DC01 finishes promoting is a normal race, not
        a failure - this is what lets the join phase wait it out instead of
        failing on the first attempt.

    .PARAMETER ComputerName
        The domain controller's FQDN to test.

    .PARAMETER TimeoutSeconds
        How long to wait before giving up.
    #>
    [CmdletBinding()]
    param(
        [string]$ComputerName = 'DC01.ad.silab.internal',

        [int]$TimeoutSeconds = 900
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $reachable = Test-NetConnection -ComputerName $ComputerName -Port 389 -InformationLevel Quiet -ErrorAction SilentlyContinue
        if ($reachable) {
            return
        }
        Start-Sleep -Seconds 15
    }

    throw "No domain controller answered at $ComputerName within $TimeoutSeconds seconds."
}

Start-SILabTranscript -ScriptName 'Bootstrap-SRV01'

try {
    # Phase 2's marker is written before Add-Computer -Restart, so a failed
    # join leaves it marked complete - phase 1 has no reboot, so needs no guard.
    Assert-SILabPhaseEffect -Number 2 -Name 'DomainJoin' -Test {
        (Get-CimInstance -ClassName Win32_ComputerSystem).PartOfDomain
    }

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

        # No rename/reboot here - the hostname changes via Add-Computer -NewName
        # during the join instead, so the join credential is consumed in the same
        # invocation it arrives in and never has to survive a reboot (PLAN.md).
        Set-SILabPhase -Number 1 -Name 'Addressing'
    }

    if (-not (Test-SILabPhaseComplete -Number 2)) {
        Wait-SILabDomainController

        $securePassword = ConvertTo-SecureString -String $DomainAdminPassword -AsPlainText -Force
        # UPN built from the domain name defined above, not a second literal - a
        # bare 'Administrator' can resolve to the local account instead, which
        # fails without saying why on an unjoined machine.
        $credential = New-Object -TypeName System.Management.Automation.PSCredential `
            -ArgumentList "Administrator@$($script:ForestDomainName)", $securePassword

        # Written before the call - Add-Computer -Restart reboots on its own, so resume must land past this phase.
        Set-SILabPhase -Number 2 -Name 'DomainJoin'
        Register-SILabResumeTask -TaskName $script:ResumeTaskName -ScriptPath $PSCommandPath

        # -NewName joins and renames in one operation, landing the computer object
        # directly in Computers/Servers instead of the default container - see
        # the credential-ordering note on task 3 for why this replaces Rename-Computer.
        Add-Computer -NewName 'SRV01' -DomainName $script:ForestDomainName -Credential $credential `
            -OUPath $script:TargetOU -Restart -Force -Confirm:$false

        # The join credential is consumed here and nowhere else on SRV01.
    }
    else {
        # Resumed after the join's reboot - nothing left to do but tidy up.
        Unregister-SILabResumeTask -TaskName $script:ResumeTaskName
    }
}
finally {
    Stop-SILabTranscript
}
