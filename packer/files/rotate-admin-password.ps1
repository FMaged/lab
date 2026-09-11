# Rotates the build-time bootstrap password (set by the answer file) to the real
# local admin password. Runs last, after every other provisioner that needs
# WinRM has already run — see the answer files' headers for why rotating it any
# earlier risks breaking Packer's own WinRM session for the rest of the build.
$ErrorActionPreference = 'Stop'

if (-not $env:ADMIN_PASSWORD) {
    throw 'ADMIN_PASSWORD environment variable is not set.'
}

net user Administrator "$env:ADMIN_PASSWORD"
if ($LASTEXITCODE -ne 0) {
    throw "net user failed with exit code $LASTEXITCODE"
}

Write-Host 'Administrator password rotated to the real value. Build finished.'
