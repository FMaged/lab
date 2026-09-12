# A separate lookup from vm-dc01.tf's — CL01 clones the Windows 11 template.
data "proxmox_virtual_environment_vms" "win11_template" {
  filter {
    name   = "name"
    values = ["tpl-win11-de-v1"] # docs/conventions.md
  }
  filter {
    name   = "template"
    values = [true]
  }

  # See the comment in vm-dc01.tf.
  lifecycle {
    postcondition {
      condition     = length(self.vms) == 1
      error_message = "Expected exactly one Proxmox template named tpl-win11-de-v1 (docs/conventions.md), used by CL01. Run the Packer build in packer/ first, or check the template was not renamed."
    }
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

  # See the comment in vm-dc01.tf — matters more here: if TPM/Secure Boot
  # silently dropped on clone, Windows 11 fails to boot outright. Matches
  # packer/windows-11.pkr.hcl's source block exactly.
  machine = "q35"
  bios    = "ovmf"

  # efi_disk: see the comment in vm-dc01.tf.
  efi_disk {
    datastore_id      = var.guest_datastore
    type              = "4m"
    pre_enrolled_keys = true
  }

  # Windows 11 requires a TPM as well as Secure Boot. The firmware side is the
  # efi_disk block above; this is the other half.
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

  # CL01 stays on DHCP permanently (docs/network-design.md) — unlike DC01/SRV01,
  # this MAC only keys the DHCP reservation, never becomes a static address.
  network_device {
    bridge      = var.proxmox_bridge_trunk
    vlan_id     = var.network_vlan_clients
    mac_address = "02:00:00:00:01:2D" # docs/conventions.md — VMID 301.
  }

  # See the comment in vm-dc01.tf. Host is CL01's DHCP-reservation address —
  # its only address, since CL01 stays on DHCP permanently.
  connection {
    type     = "winrm"
    host     = "10.10.30.50"
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

  provisioner "remote-exec" {
    inline = [
      "powershell -ExecutionPolicy Bypass -File C:/lab-provisioning/Bootstrap-CL01.ps1 -LocalAdminPassword '${local.ps_local_admin_password}' -DomainAdminPassword '${local.ps_domain_admin_password}'",
    ]
  }
}
