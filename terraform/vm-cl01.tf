# CL01 clones the Windows 11 template, not the Server one — a separate lookup
# since it's a different template.
data "proxmox_virtual_environment_vms" "win11_template" {
  filter {
    name   = "name"
    values = ["tpl-win11-de-v1"] # docs/conventions.md
  }
  filter {
    name   = "template"
    values = [true]
  }
}

resource "proxmox_virtual_environment_vm" "cl01" {
  name      = "CL01"
  node_name = var.proxmox_node
  vm_id     = 301 # docs/conventions.md — Clients VLAN (30), sequence 1.
  tags      = ["lab", "role-client"]

  clone {
    vm_id = data.proxmox_virtual_environment_vms.win11_template.vms[0].vm_id
    full  = true
  }

  # Restated explicitly, not relied on as clone inheritance — see the comment
  # in vm-dc01.tf. This one matters more than for the Server guests: if TPM or
  # Secure Boot silently dropped on clone, Windows 11 fails to boot outright.
  # Matches packer/windows-11.pkr.hcl's source block exactly.
  machine = "q35"
  bios    = "ovmf"

  efi_disk {
    datastore_id = var.guest_datastore
  }

  # No pre_enrolled_keys-equivalent argument exists on this resource — Secure
  # Boot's Microsoft keys ship enrolled in the "4m" OVMF firmware image itself,
  # not as a separate Terraform-level toggle the way Packer's plugin exposes
  # one. There is nothing more to set here for Secure Boot specifically.
  tpm_state {
    datastore_id = var.guest_datastore
    version      = "v2.0"
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
    size         = 64 # matches the template's own disk size in packer/windows-11.pkr.hcl.
  }

  # No mac-to-static mapping the way DC01/SRV01 get one — CL01 stays on DHCP
  # permanently (see docs/network-design.md), so the pinned MAC only exists to
  # key its DHCP reservation, never to be replaced by a static address later.
  network_device {
    bridge      = var.proxmox_bridge_trunk
    vlan_id     = var.network_vlan_clients
    mac_address = "02:00:00:00:01:2D" # docs/conventions.md — VMID 301.
  }
}
