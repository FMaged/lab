# Looked up by name, not VMID, so a -v2 bump is a one-line change. Shared with vm-srv01.tf.
data "proxmox_virtual_environment_vms" "winsrv2025_template" {
  filter {
    name   = "name"
    values = ["tpl-winsrv2025-de-v1"] # docs/conventions.md
  }
  filter {
    name   = "template"
    values = [true]
  }

  # Without this, a missing/renamed template fails on vms[0] with an unhelpful index error.
  lifecycle {
    postcondition {
      condition     = length(self.vms) == 1
      error_message = "Expected exactly one Proxmox template named tpl-winsrv2025-de-v1 (docs/conventions.md), used by DC01 and SRV01. Run the Packer build in packer/ first, or check the template was not renamed."
    }
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

  # Restated rather than relied on as clone inheritance — a documented provider issue drops source config on full clones.
  machine = "q35"
  bios    = "ovmf"

  # "4m" required for Secure Boot; neither this nor pre_enrolled_keys inherits from the template.
  efi_disk {
    datastore_id      = var.guest_datastore
    type              = "4m"
    pre_enrolled_keys = true
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 8192 # docs/hardware.md's per-guest RAM split.
  }

  agent {
    enabled = true
  }

  disk {
    datastore_id = var.guest_datastore
    interface    = "scsi0"
    size         = 80 # matches packer/windows-server-2025.pkr.hcl's template disk size
  }

  network_device {
    bridge      = var.proxmox_bridge_trunk
    vlan_id     = var.network_vlan_servers
    mac_address = "02:00:00:00:00:C9" # docs/conventions.md — VMID 201.
  }

  # https=false + use_ntlm=true: no cert for HTTPS, but NTLM still encrypts the payload on port 5985.
  connection {
    type     = "winrm"
    host     = "10.10.20.10"
    user     = "Administrator"
    password = var.local_admin_password
    https    = false
    use_ntlm = true
    timeout  = "10m"
  }

  provisioner "file" {
    source      = "../powershell"
    destination = "C:/lab-provisioning"
  }

  # Launches detached (Start-SILabDetached) and returns at once — waiting directly would let this
  # shell's WinRM job object kill Bootstrap-DC01.ps1 the moment the command "succeeds" and closes.
  provisioner "remote-exec" {
    inline = [
      "powershell -ExecutionPolicy Bypass -Command \"Import-Module C:/lab-provisioning/SILab.psm1 -Force; Start-SILabDetached -ScriptPath 'C:/lab-provisioning/Bootstrap-DC01.ps1' -LocalAdminPassword '${local.ps_local_admin_password}' -DomainAdminPassword '${local.ps_domain_admin_password}' -SafeModeAdminPassword '${local.ps_dsrm_recovery_password}'\"",
    ]
  }
}
