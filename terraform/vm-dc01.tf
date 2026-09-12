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

  # Machine type, BIOS/OVMF and the EFI disk all come from the template via the
  # full clone above — restating them here would just be a second place for
  # them to drift from what the template actually is.

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
