#Requires -Version 5.1
Set-StrictMode -Version Latest

# Phases run as SYSTEM after a reboot, which has no user profile - everything
# this module writes lives under C:\ProgramData instead. See AGENTS.md.
$script:SILabRoot = 'C:\ProgramData\SILab'
$script:SILabPhaseFile = Join-Path -Path $script:SILabRoot -ChildPath 'phase.json'
$script:SILabLogDir = Join-Path -Path $script:SILabRoot -ChildPath 'Logs'

function Start-SILabTranscript {
    <#
    .SYNOPSIS
        Starts a transcript for the current script run under C:\ProgramData\SILab\Logs.

    .DESCRIPTION
        Each reboot re-invokes the entry point as a new process, so this creates one
        transcript file per invocation rather than one per script - a stuck phase is
        diagnosed by reading the last file, not by scrolling through every prior boot.

    .PARAMETER ScriptName
        The calling entry point's own name (e.g. 'Bootstrap-DC01'), used in the
        transcript's file name.

    .EXAMPLE
        Start-SILabTranscript -ScriptName 'Bootstrap-DC01'
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ScriptName
    )

    if (-not (Test-Path -LiteralPath $script:SILabLogDir)) {
        $null = New-Item -Path $script:SILabLogDir -ItemType Directory -Force
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $path = Join-Path -Path $script:SILabLogDir -ChildPath "$ScriptName-$stamp.log"
    if ($PSCmdlet.ShouldProcess($path, 'Start transcript')) {
        Start-Transcript -LiteralPath $path | Out-Null
        Write-Verbose "Transcript started at $path"
    }
}

function Stop-SILabTranscript {
    <#
    .SYNOPSIS
        Stops the current transcript.

    .DESCRIPTION
        Safe to call even when no transcript is running - a phase that errors out
        before Start-SILabTranscript runs must not fail a second time on cleanup.

    .EXAMPLE
        Stop-SILabTranscript
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess('Current transcript', 'Stop transcript')) {
        try {
            Stop-Transcript -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Verbose 'No transcript was running.'
        }
    }
}

function Get-SILabPhase {
    <#
    .SYNOPSIS
        Returns the highest phase number this guest has completed.

    .DESCRIPTION
        Reads the marker Set-SILabPhase writes. Returns 0 when no phase has
        completed yet, so a caller can compare with -ge/-lt without a null check.

    .OUTPUTS
        [int]

    .EXAMPLE
        Get-SILabPhase
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param()

    if (-not (Test-Path -LiteralPath $script:SILabPhaseFile)) {
        return 0
    }

    $marker = Get-Content -LiteralPath $script:SILabPhaseFile -Raw -Encoding UTF8 | ConvertFrom-Json
    return [int]$marker.Number
}

function Test-SILabPhaseComplete {
    <#
    .SYNOPSIS
        Guard that makes re-running a completed phase a no-op.

    .DESCRIPTION
        Every entry point checks this before doing a phase's work, so a retried
        script (after a crash, or a manual re-run) never repeats a phase that
        already succeeded.

    .PARAMETER Number
        The phase number to check.

    .OUTPUTS
        [bool]

    .EXAMPLE
        if (-not (Test-SILabPhaseComplete -Number 2)) { # run phase 2 }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Number
    )

    return (Get-SILabPhase) -ge $Number
}

function Set-SILabPhase {
    <#
    .SYNOPSIS
        Records that a phase has completed.

    .DESCRIPTION
        Call this before an action that reboots or restarts the machine on its own
        (Install-ADDSForest, Add-Computer -Restart) - writing it after the call
        never runs, and the resume would repeat the phase that just rebooted.

    .PARAMETER Number
        The phase number that has completed.

    .PARAMETER Name
        A short human-readable name for the phase, kept in the marker file for
        anyone reading it directly.

    .EXAMPLE
        Set-SILabPhase -Number 2 -Name 'Promotion'
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Number,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    if (-not (Test-Path -LiteralPath $script:SILabRoot)) {
        $null = New-Item -Path $script:SILabRoot -ItemType Directory -Force
    }

    if ($PSCmdlet.ShouldProcess($script:SILabPhaseFile, "Set phase marker to $Number ($Name)")) {
        $marker = [PSCustomObject]@{
            Number    = $Number
            Name      = $Name
            Timestamp = (Get-Date).ToString('o')
        }
        $json = $marker | ConvertTo-Json -Depth 5
        # Set-Content defaults to ANSI in 5.1; write UTF-8 without a BOM explicitly.
        $utf8NoBom = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false
        [System.IO.File]::WriteAllText($script:SILabPhaseFile, $json, $utf8NoBom)
    }
}

function Register-SILabResumeTask {
    <#
    .SYNOPSIS
        Registers a scheduled task that re-runs an entry point script at the next
        startup, so a multi-phase script survives its own reboots.

    .DESCRIPTION
        Runs as SYSTEM and triggers at startup rather than logon, since nobody logs
        on to these guests between phases. -Force makes registering an
        already-registered task a no-op replace rather than an error.

    .PARAMETER TaskName
        The scheduled task's name.

    .PARAMETER ScriptPath
        Full path to the entry point script to re-run, e.g. $PSCommandPath.

    .EXAMPLE
        Register-SILabResumeTask -TaskName 'SILab-Resume' -ScriptPath $PSCommandPath
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TaskName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ScriptPath
    )

    if ($PSCmdlet.ShouldProcess($TaskName, 'Register resume scheduled task')) {
        $argument = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}"' -f $ScriptPath
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argument
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
        Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
    }
}

function Unregister-SILabResumeTask {
    <#
    .SYNOPSIS
        Removes the resume scheduled task once the last phase has completed.

    .DESCRIPTION
        A no-op when the task does not exist, so the last phase of every entry
        point can call this unconditionally.

    .PARAMETER TaskName
        The scheduled task's name.

    .EXAMPLE
        Unregister-SILabResumeTask -TaskName 'SILab-Resume'
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TaskName
    )

    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($null -eq $existing) {
        return
    }

    if ($PSCmdlet.ShouldProcess($TaskName, 'Unregister resume scheduled task')) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }
}

function Assert-SILabPhaseEffect {
    <#
    .SYNOPSIS
        Fail loudly when a phase is marked complete but its effect is absent.

    .DESCRIPTION
        A phase whose work ends in a reboot must write its marker *before* the
        call, because the call never returns. The cost is that a failed phase is
        indistinguishable from a successful one: the marker is set either way, so
        a re-run skips the phase, tidies up and exits zero, having achieved
        nothing.

        This closes that gap for any phase whose result can be checked directly.
        Call it before the phase guards, once per such phase.

    .PARAMETER Number
        The phase number to check.

    .PARAMETER Name
        The phase name, used in the error message.

    .PARAMETER Test
        A scriptblock returning $true when the phase's effect is present. Only
        evaluated if the phase is marked complete.

    .EXAMPLE
        Assert-SILabPhaseEffect -Number 1 -Name 'DomainJoin' -Test {
            (Get-CimInstance -ClassName Win32_ComputerSystem).PartOfDomain
        }

        Throws if phase 1 is marked complete but the machine is not joined.

    .OUTPUTS
        None. Throws on inconsistency.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [int]$Number,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [scriptblock]$Test
    )

    if (-not (Test-SILabPhaseComplete -Number $Number)) {
        return
    }

    if (-not (& $Test)) {
        throw ("Phase $Number ($Name) is marked complete but its effect is absent. " +
            'The marker is written before the call that reboots, so a failure during ' +
            'that call leaves exactly this state. Read the transcript under ' +
            'C:\ProgramData\SILab\Logs to find the cause; the phase marker has to be ' +
            'corrected by hand before re-running.')
    }
}

function Start-SILabDetached {
    <#
    .SYNOPSIS
        Launches a Bootstrap entry point as a detached process, outside the
        WinRM shell's own job object, and returns.

    .DESCRIPTION
        Terraform's WinRM provisioner blocks on the command it runs and tears
        the session down the instant that command returns - which closes this
        shell's Windows job object and kills anything started directly inside
        it, `Start-Process` included (PowerShell/PowerShell#16001). A one-shot
        scheduled task escapes that job entirely, because Task Scheduler spawns
        its own process tree outside it - the same mechanism Packer's own
        elevated-command provisioner and Ansible's Windows modules use for
        exactly this problem (PLAN.md's orchestration SPIKE). The task
        definition is deleted again immediately after its process starts, so
        whatever credential its argument list carries sits on disk for a
        moment, never longer - the least-bad option available, not a clean
        one; see the SPIKE for what else was considered and rejected.

    .PARAMETER ScriptPath
        Full path to the entry point script to launch (e.g. Bootstrap-DC01.ps1).

    .PARAMETER LocalAdminPassword
        Forwarded to the entry point as -LocalAdminPassword, only if bound.

    .PARAMETER DomainAdminPassword
        Forwarded to the entry point as -DomainAdminPassword, only if bound.

    .PARAMETER SafeModeAdminPassword
        Forwarded to the entry point as -SafeModeAdminPassword, only if bound -
        DC01 only; SRV01 and CL01's entry points have no such parameter, and
        passing it to them would fail to bind rather than being ignored.

    .EXAMPLE
        Start-SILabDetached -ScriptPath 'C:\lab-provisioning\Bootstrap-DC01.ps1' -DomainAdminPassword 'x'
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'LocalAdminPassword', Justification = 'Received as a plain command-line argument from Terraform; see the credential decision in PLAN.md.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'DomainAdminPassword', Justification = 'Received as a plain command-line argument from Terraform; see the credential decision in PLAN.md.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'SafeModeAdminPassword', Justification = 'Received as a plain command-line argument from Terraform; see the credential decision in PLAN.md.')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ScriptPath,

        [string]$LocalAdminPassword,

        [string]$DomainAdminPassword,

        [string]$SafeModeAdminPassword
    )

    # Doubles an embedded ' the way terraform/locals.tf already does for the
    # first layer of quoting - this is a second, independent layer (this
    # value's new home is the scheduled task's own argument string), so it
    # needs escaping again here rather than trusting the caller's escaping to
    # still hold.
    function ConvertTo-SingleQuotedLiteral {
        param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
        return "'" + $Value.Replace("'", "''") + "'"
    }

    $argumentParts = @('-ExecutionPolicy', 'Bypass', '-File', (ConvertTo-SingleQuotedLiteral $ScriptPath))
    if ($PSBoundParameters.ContainsKey('LocalAdminPassword')) {
        $argumentParts += '-LocalAdminPassword', (ConvertTo-SingleQuotedLiteral $LocalAdminPassword)
    }
    if ($PSBoundParameters.ContainsKey('DomainAdminPassword')) {
        $argumentParts += '-DomainAdminPassword', (ConvertTo-SingleQuotedLiteral $DomainAdminPassword)
    }
    if ($PSBoundParameters.ContainsKey('SafeModeAdminPassword')) {
        $argumentParts += '-SafeModeAdminPassword', (ConvertTo-SingleQuotedLiteral $SafeModeAdminPassword)
    }
    $taskArgument = $argumentParts -join ' '
    $taskName = 'SILab-Launch-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)

    if (-not $PSCmdlet.ShouldProcess($ScriptPath, 'Launch detached via a one-shot scheduled task')) {
        return
    }

    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $taskArgument
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date)
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null

    try {
        Start-ScheduledTask -TaskName $taskName

        # Task Scheduler dispatches asynchronously - wait for the process to
        # actually start before deleting the definition below, or deletion
        # can race the launch itself.
        $deadline = (Get-Date).AddSeconds(30)
        do {
            Start-Sleep -Milliseconds 200
            $state = (Get-ScheduledTask -TaskName $taskName).State
        } while ($state -ne 'Running' -and (Get-Date) -lt $deadline)

        if ($state -ne 'Running') {
            throw "Scheduled task '$taskName' did not start within 30 seconds."
        }
    }
    finally {
        # Removing the definition does not stop the instance Task Scheduler
        # already launched - only future runs. That instance is now a child
        # of the Task Scheduler service, not of this WinRM shell, so it
        # outlives this command and this session either way.
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
}

Export-ModuleMember -Function @(
    'Start-SILabTranscript',
    'Stop-SILabTranscript',
    'Get-SILabPhase',
    'Test-SILabPhaseComplete',
    'Assert-SILabPhaseEffect',
    'Set-SILabPhase',
    'Register-SILabResumeTask',
    'Unregister-SILabResumeTask',
    'Start-SILabDetached'
)
