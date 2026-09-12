# Copy to packer.auto.pkrvars.hcl (gitignored) and adjust node/datastore/ISO names.
# Credentials go in .env as PKR_VAR_* entries instead — see example.env, PLAN.md.

proxmox_node = "pve"

iso_datastore      = "local"
template_datastore = "local-lvm"

win_server_iso_file     = "win-server-2025-de.iso"
win_server_iso_checksum = "sha256:REPLACE_ME"

win11_iso_file     = "win-11-pro-de.iso"
win11_iso_checksum = "sha256:REPLACE_ME"

virtio_iso_file     = "virtio-win-0.1.285.iso"
virtio_iso_checksum = "sha256:REPLACE_ME"

opnsense_iso_file     = "OPNsense-26.7-dvd-amd64.iso"
opnsense_iso_checksum = "sha256:REPLACE_ME"
