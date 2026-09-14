# Mirrors vm-dc01.tf apart from name, vm_id, mac_address and role tag; the template
# lookup data source referenced below lives there, shared by both files.
resource "proxmox_virtual_environment_vm" "srv01" {
  name      = "SRV01"
  node_name = var.proxmox_node
  vm_id     = 202 # docs/conventions.md — Servers VLAN (20), sequence 2.
  tags      = ["lab", "role-member-server"]

  clone {
    vm_id = data.proxmox_virtual_environment_vms.winsrv2025_template.vms[0].vm_id
    full  = true
  }

  # Restated, not relied on as inheritance — see the comment in vm-dc01.tf.
  machine = "q35"
  bios    = "ovmf"

  # efi_disk: see the comment in vm-dc01.tf.
  efi_disk {
    datastore_id      = var.guest_datastore
    type              = "4m"
    pre_enrolled_keys = true
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
    size         = 80 # matches the template's own disk size in packer/windows-server-2025.pkr.hcl.
  }

  network_device {
    bridge      = var.proxmox_bridge_trunk
    vlan_id     = var.network_vlan_servers
    mac_address = "02:00:00:00:00:CA" # docs/conventions.md — VMID 202.
  }

  # See the comment in vm-dc01.tf. Host is SRV01's DHCP-reservation address.
  connection {
    type     = "winrm"
    host     = "10.10.20.11"
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

  # Launches detached via Start-SILabDetached — see the comment in vm-dc01.tf.
  provisioner "remote-exec" {
    inline = [
      "powershell -ExecutionPolicy Bypass -Command \"Import-Module C:/lab-provisioning/SILab.psm1 -Force; Start-SILabDetached -ScriptPath 'C:/lab-provisioning/Bootstrap-SRV01.ps1' -LocalAdminPassword '${local.ps_local_admin_password}' -DomainAdminPassword '${local.ps_domain_admin_password}'\"",
    ]
  }
}
