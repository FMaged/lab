# Copy to packer.auto.pkrvars.hcl (gitignored) and adjust node/datastore/URLs.
# Credentials go in .env as PKR_VAR_* entries instead — see example.env, PLAN.md.

proxmox_node = "pve"

proxmox_bridge_build = "vmbr2"

iso_datastore      = "local"
template_datastore = "local-lvm"

# Proxmox downloads these three itself (iso_download_pve) — nothing crosses the
# operator's connection, only the host's. Each URL's filename must match the
# Packer templates table in docs/conventions.md exactly (win-server-2025-de.iso,
# win-11-pro-de.iso, virtio-win-<version>.iso), since that filename becomes the
# datastore path every source block reads back.
win_server_iso_url      = "https://example.invalid/win-server-2025-de.iso"
win_server_iso_checksum = "sha256:REPLACE_ME"

win11_iso_url      = "https://example.invalid/win-11-pro-de.iso"
win11_iso_checksum = "sha256:REPLACE_ME"

virtio_iso_url      = "https://example.invalid/virtio-win-0.1.285.iso"
virtio_iso_checksum = "sha256:REPLACE_ME"

# OPNsense ships as .iso.bz2 — the host-side runner downloads and decompresses
# opnsense_iso_url into opnsense_iso_file itself before `packer build` runs, and
# verifies opnsense_iso_checksum by hand. Packer never downloads this one.
opnsense_iso_file     = "OPNsense-26.7-dvd-amd64.iso"
opnsense_iso_checksum = "sha256:REPLACE_ME"
opnsense_iso_url      = "https://example.invalid/OPNsense-26.7-dvd-amd64.iso.bz2"
