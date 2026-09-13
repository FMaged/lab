# Driver ISO comes from the source block's additional_iso_files. Finds the
# CD-ROM dynamically rather than assuming a letter — same reason the answer
# files hedge their driver paths across D:/E:/F:. The answer file's own
# FirstLogonCommands now runs this same install before WinRM exists at all
# (so qemu_agent can address the VM at all) — this provisioner still runs
# too, idempotently, as a second attempt in case that inline copy failed.
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

# -PassThru catches the exit code — a native installer doesn't set $LASTEXITCODE
# via Start-Process, so a failed install would otherwise be silent (and the first
# symptom would be Terraform hanging on `agent { enabled = true }`). 3010 means
# success, reboot required, expected with /norestart.
$process = Start-Process -FilePath $installer -ArgumentList '/install', '/quiet', '/norestart' `
    -Wait -NoNewWindow -PassThru

if ($process.ExitCode -notin @(0, 3010)) {
    throw "Guest tools installer failed with exit code $($process.ExitCode)."
}
