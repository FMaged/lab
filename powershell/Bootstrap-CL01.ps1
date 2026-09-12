#Requires -Version 5.1
[CmdletBinding()]
# Both parameters arrive as plain strings because Terraform passes command-line
# arguments and this script cannot receive a SecureString directly (see the
# credential decision in PLAN.md). LocalAdminPassword is unused for the whole
# script - it only ever authenticates Terraform's own WinRM connection - but
# is declared anyway because every guest's Bootstrap script takes the same
# fixed parameters (AGENTS.md). DomainAdminPassword is used by the join phase,
# below.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'LocalAdminPassword', Justification = 'Terraform passes this as a plain command-line argument; see the credential decision in PLAN.md.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'DomainAdminPassword', Justification = 'Terraform passes this as a plain command-line argument; see the credential decision in PLAN.md.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'The domain admin password arrives as a plain command-line argument and is converted to a SecureString on first use; see the credential decision in PLAN.md.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'LocalAdminPassword', Justification = 'Every guest Bootstrap script takes the same fixed parameters; CL01 does not need this one.')]
param(
    [string]$LocalAdminPassword,
    [string]$DomainAdminPassword
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path -Path $PSScriptRoot -ChildPath 'SILab.psm1') -Force

$script:ResumeTaskName = 'SILab-Resume-CL01'

# docs/ad-design.md.
$script:ForestDomainName = 'ad.silab.internal'
$script:TargetOU = 'OU=Workstations,OU=Computers,OU=SILAB,DC=ad,DC=silab,DC=internal'

function Wait-SILabDomainController {
    <#
    .SYNOPSIS
        Blocks until a domain controller answers on LDAP.

    .DESCRIPTION
        CL01 booting before DC01 finishes promoting is a normal race, not a
        failure - this is what lets the join phase wait it out instead of
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

Start-SILabTranscript -ScriptName 'Bootstrap-CL01'

try {
    if (-not (Test-SILabPhaseComplete -Number 1)) {
        # CL01 stays on DHCP permanently (docs/network-design.md) - no
        # addressing phase of its own, unlike DC01/SRV01.
        Wait-SILabDomainController

        $securePassword = ConvertTo-SecureString -String $DomainAdminPassword -AsPlainText -Force
        $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'Administrator', $securePassword

        # Written before the call, not after: Add-Computer -Restart reboots on
        # its own, so the resume must land past this phase, not repeat it.
        Set-SILabPhase -Number 1 -Name 'DomainJoin'
        Register-SILabResumeTask -TaskName $script:ResumeTaskName -ScriptPath $PSCommandPath

        # -NewName joins and renames in one supported operation, landing the
        # computer object directly in Computers/Workstations rather than the
        # default container and a later move.
        Add-Computer -NewName 'CL01' -DomainName $script:ForestDomainName -Credential $credential `
            -OUPath $script:TargetOU -Restart -Force -Confirm:$false

        # The join credential is consumed here and nowhere else on CL01 - this
        # is CL01's only phase.
    }
    else {
        # Resumed after the join's reboot - nothing left to do but tidy up.
        Unregister-SILabResumeTask -TaskName $script:ResumeTaskName
    }
}
finally {
    Stop-SILabTranscript
}
