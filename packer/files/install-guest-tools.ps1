# Finds the CD-ROM dynamically rather than assuming a letter, same as the answer files' driver paths.
# The answer file's FirstLogonCommands already runs this install once; this is an idempotent retry.
$ErrorActionPreference = 'Stop'

$installer = Get-Volume |
    Where-Object { $_.DriveType -eq 'CD-ROM' -and $_.DriveLetter } |
    ForEach-Object { Join-Path "$($_.DriveLetter):\" 'virtio-win-guest-tools.exe' } |
    Where-Object { Test-Path $_ } |
    Select-Object -First 1

if (-not $installer) {
    throw 'virtio-win-guest-tools.exe not found on any attached CD-ROM.'
}

Write-Host "Installing guest tools from $installer"

# -PassThru catches the exit code - Start-Process doesn't set $LASTEXITCODE for native installers.
# 3010 means success, reboot required, expected with /norestart.
$process = Start-Process -FilePath $installer -ArgumentList '/install', '/quiet', '/norestart' `
    -Wait -NoNewWindow -PassThru

if ($process.ExitCode -notin @(0, 3010)) {
    throw "Guest tools installer failed with exit code $($process.ExitCode)."
}
