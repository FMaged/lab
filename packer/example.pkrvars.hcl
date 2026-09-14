# Copy to packer.auto.pkrvars.hcl (gitignored) and adjust node/datastore/URLs.
# Credentials go in .env as PKR_VAR_* entries instead — see example.env, PLAN.md.

proxmox_node = "pve"

proxmox_bridge_build = "vmbr2"

iso_datastore      = "local"
template_datastore = "local-lvm"

# Proxmox downloads these three itself (iso_download_pve). Each URL's filename must match the
# Packer templates table in docs/conventions.md exactly, since it becomes the datastore path.
win_server_iso_url      = "https://example.invalid/win-server-2025-de.iso"
win_server_iso_checksum = "sha256:REPLACE_ME"

win11_iso_url      = "https://example.invalid/win-11-pro-de.iso"
win11_iso_checksum = "sha256:REPLACE_ME"

virtio_iso_url      = "https://example.invalid/virtio-win-0.1.285.iso"
virtio_iso_checksum = "sha256:REPLACE_ME"

# OPNsense ships as .iso.bz2 — host-runner.sh downloads, decompresses and verifies this one itself.
opnsense_iso_file     = "OPNsense-26.7-dvd-amd64.iso"
opnsense_iso_checksum = "sha256:REPLACE_ME"
opnsense_iso_url      = "https://example.invalid/OPNsense-26.7-dvd-amd64.iso.bz2"
