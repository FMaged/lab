# Must run last — WinRM authenticates with the bootstrap password, so rotating
# it earlier breaks every later provisioner's connection.
$ErrorActionPreference = 'Stop'

if (-not $env:ADMIN_PASSWORD) {
    throw 'ADMIN_PASSWORD environment variable is not set.'
}

net user Administrator "$env:ADMIN_PASSWORD"
if ($LASTEXITCODE -ne 0) {
    throw "net user failed with exit code $LASTEXITCODE"
}

Write-Host 'Administrator password rotated to the real value. Build finished.'
