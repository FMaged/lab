#Requires -Version 5.1
[CmdletBinding()]
# Both arrive as plain strings, not SecureString - Terraform passes them as CLI args.
# LocalAdminPassword is unused here; every guest script takes the same fixed parameters.
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
        CL01 booting before DC01 finishes promoting is a normal race, not a failure.

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
    Assert-SILabPhaseEffect -Number 1 -Name 'DomainJoin' -Test {
        (Get-CimInstance -ClassName Win32_ComputerSystem).PartOfDomain
    }

    if (-not (Test-SILabPhaseComplete -Number 1)) {
        # CL01 stays on DHCP permanently - no addressing phase of its own, unlike DC01/SRV01.
        Wait-SILabDomainController

        $securePassword = ConvertTo-SecureString -String $DomainAdminPassword -AsPlainText -Force
        # UPN, not a bare 'Administrator' - that can resolve to the local account instead.
        $credential = New-Object -TypeName System.Management.Automation.PSCredential `
            -ArgumentList "Administrator@$($script:ForestDomainName)", $securePassword

        # Written before the call - Add-Computer -Restart reboots on its own, so resume must land past this phase.
        Set-SILabPhase -Number 1 -Name 'DomainJoin'
        Register-SILabResumeTask -TaskName $script:ResumeTaskName -ScriptPath $PSCommandPath

        # -NewName joins and renames in one operation, landing the computer object in Computers/Workstations directly.
        Add-Computer -NewName 'CL01' -DomainName $script:ForestDomainName -Credential $credential `
            -OUPath $script:TargetOU -Restart -Force -Confirm:$false
    }
    else {
        Unregister-SILabResumeTask -TaskName $script:ResumeTaskName
    }
}
finally {
    Stop-SILabTranscript
}
