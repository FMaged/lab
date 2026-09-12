# Mirrors vm-dc01.tf exactly apart from name, vm_id, mac_address and the role
# tag — the two guests share every structural choice, and duplicating four
# lines is simpler than a module for two resources. See the
# simplest-thing-that-works rule in PLAN.md. The template lookup data source
# lives in vm-dc01.tf; both files share this root, so it needs declaring once.
resource "proxmox_virtual_environment_vm" "srv01" {
  name      = "SRV01"
  node_name = var.proxmox_node
  vm_id     = 202 # docs/conventions.md — Servers VLAN (20), sequence 2.
  tags      = ["lab", "role-member-server"]

  clone {
    vm_id = data.proxmox_virtual_environment_vms.winsrv2025_template.vms[0].vm_id
    full  = true
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 4096 # docs/hardware.md's per-guest RAM split.
  }

  agent {
    enabled = true
  }

  disk {
    datastore_id = var.guest_datastore
    interface    = "scsi0"
    size         = 80
  }

  network_device {
    bridge      = var.proxmox_bridge_trunk
    vlan_id     = var.network_vlan_servers
    mac_address = "02:00:00:00:00:CA" # docs/conventions.md — VMID 202.
  }
}
