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

  # Terraform's last act for this guest: bring it up, then hand off to
  # powershell/ — never AD commands inline here, per the terraform-proxmox
  # skill. Host is the DHCP-reservation address (opnsense/dhcp.tf task 3) — the
  # only address DC01 has until its own first-boot script makes it static.
  connection {
    type     = "winrm"
    host     = "10.10.20.10"
    user     = "Administrator"
    password = var.local_admin_password
    https    = false
    timeout  = "10m"
  }

  provisioner "file" {
    source      = "../powershell"
    destination = "C:/lab-provisioning"
  }

  # One entry point, no chain of inline AD commands, per the skill.
  # SafeModeAdminPassword is DC01-only — SRV01/CL01 have no forest to
  # recover, so neither of their invocations takes this argument.
  provisioner "remote-exec" {
    inline = [
      "powershell -ExecutionPolicy Bypass -File C:/lab-provisioning/Bootstrap-DC01.ps1 -LocalAdminPassword '${var.local_admin_password}' -DomainAdminPassword '${var.domain_admin_password}' -SafeModeAdminPassword '${var.dsrm_recovery_password}'",
    ]
  }
}
