#Requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module ActiveDirectory -ErrorAction Stop
Import-Module GroupPolicy -ErrorAction Stop

$script:FailureCount = 0

function Test-SILabCheck {
    <#
    .SYNOPSIS
        Runs one read-only check and prints a pass/fail line.

    .DESCRIPTION
        Every check in this script is read-only - this wrapper is what turns
        each one into a single reportable line and a running failure count,
        rather than each check needing its own try/catch and Write-Output.

    .PARAMETER Description
        What is being checked, printed alongside the result.

    .PARAMETER Test
        A scriptblock returning $true for a pass, $false (or throwing) for a
        failure.

    .EXAMPLE
        Test-SILabCheck -Description 'Forest name is correct' -Test { (Get-ADDomain).DNSRoot -eq 'ad.silab.internal' }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Description,

        [Parameter(Mandatory)]
        [scriptblock]$Test
    )

    try {
        $result = & $Test
    }
    catch {
        $result = $false
    }

    if ($result) {
        Write-Output "[PASS] $Description"
    }
    else {
        Write-Output "[FAIL] $Description"
        $script:FailureCount++
    }
}

# Forest and domain - docs/ad-design.md.
Test-SILabCheck -Description 'Forest/domain name is ad.silab.internal' -Test {
    (Get-ADDomain).DNSRoot -eq 'ad.silab.internal'
}
Test-SILabCheck -Description 'NetBIOS name is SILAB' -Test {
    (Get-ADDomain).NetBIOSName -eq 'SILAB'
}
Test-SILabCheck -Description 'Domain functional level is 2025' -Test {
    (Get-ADDomain).DomainMode -like '*2025*'
}
Test-SILabCheck -Description 'Forest functional level is 2025' -Test {
    (Get-ADForest).ForestMode -like '*2025*'
}
Test-SILabCheck -Description 'Default site was renamed to SILAB-Lab' -Test {
    $null -ne (Get-ADReplicationSite -Filter "Name -eq 'SILAB-Lab'" -ErrorAction SilentlyContinue)
}

# OU tree - docs/ad-design.md, node for node.
$domainDN = (Get-ADDomain).DistinguishedName
$ouPaths = [ordered]@{
    'SILAB'                        = "OU=SILAB,$domainDN"
    'SILAB/Computers'              = "OU=Computers,OU=SILAB,$domainDN"
    'SILAB/Computers/Servers'      = "OU=Servers,OU=Computers,OU=SILAB,$domainDN"
    'SILAB/Computers/Workstations' = "OU=Workstations,OU=Computers,OU=SILAB,$domainDN"
    'SILAB/Users'                  = "OU=Users,OU=SILAB,$domainDN"
    'SILAB/Groups'                 = "OU=Groups,OU=SILAB,$domainDN"
    'SILAB/Service Accounts'       = "OU=Service Accounts,OU=SILAB,$domainDN"
}
foreach ($name in $ouPaths.Keys) {
    $path = $ouPaths[$name]
    Test-SILabCheck -Description "OU $name exists" -Test {
        $null -ne (Get-ADOrganizationalUnit -Identity $path -ErrorAction SilentlyContinue)
    }
}

# Groups - docs/ad-design.md.
foreach ($groupName in 'SILAB-Admins', 'SILAB-Helpdesk') {
    Test-SILabCheck -Description "Group $groupName is a global security group" -Test {
        $group = Get-ADGroup -Filter "Name -eq '$groupName'" -Properties GroupCategory, GroupScope -ErrorAction SilentlyContinue
        $null -ne $group -and $group.GroupCategory -eq 'Security' -and $group.GroupScope -eq 'Global'
    }
}

# Baseline GPOs - docs/ad-design.md: each exists, linked to the container that table names.
$gpoChecks = @(
    @{ Name = 'Domain Password & Lockout Policy'; Target = $domainDN },
    @{ Name = 'Workstation Baseline'; Target = $ouPaths['SILAB/Computers/Workstations'] },
    @{ Name = 'Server Baseline'; Target = $ouPaths['SILAB/Computers/Servers'] }
)
foreach ($check in $gpoChecks) {
    $gpoName = $check.Name
    $target = $check.Target
    Test-SILabCheck -Description "GPO '$gpoName' exists and is linked at $target" -Test {
        $gpo = Get-GPO -Name $gpoName -ErrorAction SilentlyContinue
        if ($null -eq $gpo) {
            return $false
        }
        $links = (Get-GPInheritance -Target $target).GpoLinks
        $null -ne ($links | Where-Object { $_.GpoId -eq $gpo.Id })
    }
}

# Member joins - docs/ad-design.md places each in a specific OU by role.
Test-SILabCheck -Description 'SRV01 computer object is in Computers/Servers' -Test {
    $computer = Get-ADComputer -Filter "Name -eq 'SRV01'" -ErrorAction SilentlyContinue
    $null -ne $computer -and $computer.DistinguishedName -like "*,$($ouPaths['SILAB/Computers/Servers'])"
}
Test-SILabCheck -Description 'CL01 computer object is in Computers/Workstations' -Test {
    $computer = Get-ADComputer -Filter "Name -eq 'CL01'" -ErrorAction SilentlyContinue
    $null -ne $computer -and $computer.DistinguishedName -like "*,$($ouPaths['SILAB/Computers/Workstations'])"
}

if ($script:FailureCount -gt 0) {
    Write-Output "$script:FailureCount check(s) failed."
    exit 1
}

Write-Output 'All checks passed.'
exit 0
