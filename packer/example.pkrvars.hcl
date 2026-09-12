# Copy to packer.auto.pkrvars.hcl (gitignored) and adjust if your node, datastores
# or ISO filenames differ. No credentials here — the Proxmox token and the local
# admin password are PKR_VAR_* entries in the root .env. See example.env and the
# secrets decision in PLAN.md.

proxmox_node = "pve"

iso_datastore      = "local"
template_datastore = "local-lvm"

win_server_iso_file     = "win-server-2025-de.iso"
win_server_iso_checksum = "sha256:REPLACE_ME"

win11_iso_file     = "win-11-pro-de.iso"
win11_iso_checksum = "sha256:REPLACE_ME"

virtio_iso_file     = "virtio-win-0.1.285.iso"
virtio_iso_checksum = "sha256:REPLACE_ME"
