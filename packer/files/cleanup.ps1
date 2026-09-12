# Deliberately does NOT sysprep or generalize the image (PLAN.md no-sysprep
# decision) — only removes build-time debris.
$ErrorActionPreference = 'Stop'

Write-Host 'Clearing the Windows Update download cache...'
Stop-Service wuauserv -Force
Remove-Item -Path "$env:WINDIR\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
Start-Service wuauserv

Write-Host 'Clearing temp files...'
Remove-Item -Path "$env:WINDIR\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host 'Clearing event logs...'
Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        [System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog($_.LogName)
    } catch {
        # Security and some Analytic/Debug logs refuse to clear this way — not worth failing the build over.
    }
}

Write-Host 'Cleanup complete. No sysprep — see PLAN.md.'
