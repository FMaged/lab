#Requires -Version 5.1
[CmdletBinding()]
# Both parameters arrive as plain strings because Terraform passes command-line
# arguments and this script cannot receive a SecureString directly (see the
# credential decision in PLAN.md). LocalAdminPassword is unused for the whole
# script - it only ever authenticates Terraform's own WinRM connection - but
# is declared anyway because every guest's Bootstrap script takes the same
# fixed parameters (AGENTS.md). DomainAdminPassword is used by phase 2, below.
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
# DC01 - already promoted by the time SRV01 runs, per runbook.md section 5's
# ordering (DC01's own apply is targeted and completed first).
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
    # Phase 2's marker is written before Add-Computer -Restart, so a failed join
    # leaves it marked complete on an unjoined machine. Phase 1 needs no such
    # guard: it has no reboot, so its marker is only reached on success.
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

        # No rename and no reboot here. SRV01's hostname changes via
        # Add-Computer -NewName during the domain join (task 7) instead of a
        # separate Rename-Computer call, so the join credential is consumed in
        # the same invocation that receives it and never has to survive a
        # reboot. See the credential-ordering decision in PLAN.md.
        Set-SILabPhase -Number 1 -Name 'Addressing'
    }

    if (-not (Test-SILabPhaseComplete -Number 2)) {
        Wait-SILabDomainController

        $securePassword = ConvertTo-SecureString -String $DomainAdminPassword -AsPlainText -Force
        $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'Administrator', $securePassword

        # Written before the call, not after: Add-Computer -Restart reboots on
        # its own, so the resume must land past this phase, not repeat it.
        Set-SILabPhase -Number 2 -Name 'DomainJoin'
        Register-SILabResumeTask -TaskName $script:ResumeTaskName -ScriptPath $PSCommandPath

        # -NewName joins and renames in one supported operation, landing the
        # computer object directly in Computers/Servers rather than the
        # default container and a later move - see the credential-ordering
        # note on task 3 for why this replaces a separate Rename-Computer.
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
