# Looked up by name, not a hardcoded VMID — bumping the template to -v2 is then
# a one-line change here, not a search-and-replace across every guest that
# clones it. Shared with vm-srv01.tf, which clones the same template.
data "proxmox_virtual_environment_vms" "winsrv2025_template" {
  filter {
    name   = "name"
    values = ["tpl-winsrv2025-de-v1"] # docs/conventions.md
  }
  filter {
    name   = "template"
    values = [true]
  }
}

resource "proxmox_virtual_environment_vm" "dc01" {
  name      = "DC01"
  node_name = var.proxmox_node
  vm_id     = 201 # docs/conventions.md — Servers VLAN (20), sequence 1.
  tags      = ["lab", "role-dc"]

  clone {
    vm_id = data.proxmox_virtual_environment_vms.winsrv2025_template.vms[0].vm_id
    full  = true
  }

  # Restated explicitly rather than relied on as clone inheritance — the
  # provider's own clone guide is not fully specific about which fields
  # inherit and which fall back to schema defaults, and a documented issue
  # exists where a full clone did not carry over the source's full config.
  # Matches packer/windows-server-2025.pkr.hcl's source block exactly.
  machine = "q35"
  bios    = "ovmf"

  efi_disk {
    datastore_id = var.guest_datastore
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 8192 # docs/hardware.md's per-guest RAM split.
  }

  agent {
    enabled = true # unlike OPNsense, this image has qemu-guest-agent installed.
  }

  disk {
    datastore_id = var.guest_datastore
    interface    = "scsi0"
    size         = 80
  }

  network_device {
    bridge      = var.proxmox_bridge_trunk
    vlan_id     = var.network_vlan_servers
    mac_address = "02:00:00:00:00:C9" # docs/conventions.md — VMID 201.
  }
}
