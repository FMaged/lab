# Installs the QEMU guest agent and the rest of the VirtIO driver set from the ISO
# the source block already attached (see additional_iso_files). Finds the CD-ROM
# drive dynamically rather than assuming a letter, for the same reason the answer
# files hedge their driver paths across D:/E:/F:.
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
Start-Process -FilePath $installer -ArgumentList '/install', '/quiet', '/norestart' -Wait -NoNewWindow
