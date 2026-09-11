# Copy to packer.auto.pkrvars.hcl (gitignored) and fill in real values, or set
# the equivalent PKR_VAR_* environment variables — never commit real values here.
# See the secrets decision in PLAN.md.

proxmox_url              = "https://proxmox.example.internal:8006/api2/json"
proxmox_node             = "pve"
proxmox_api_token_id     = "root@pam!packer"
proxmox_api_token_secret = "REPLACE_ME"

iso_datastore       = "local"
template_datastore  = "local-lvm"

win_server_iso_file     = "win-server-2025-de.iso"
win_server_iso_checksum = "sha256:REPLACE_ME"

win11_iso_file     = "win-11-pro-de.iso"
win11_iso_checksum = "sha256:REPLACE_ME"

virtio_iso_file     = "virtio-win-0.1.285.iso"
virtio_iso_checksum = "sha256:REPLACE_ME"

local_admin_password = "REPLACE_ME"
