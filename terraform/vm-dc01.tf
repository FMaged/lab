# Looked up by name, not a hardcoded VMID — bumping to -v2 is then a one-line
# change here, not a search-and-replace. Shared with vm-srv01.tf.
data "proxmox_virtual_environment_vms" "winsrv2025_template" {
  filter {
    name   = "name"
    values = ["tpl-winsrv2025-de-v1"] # docs/conventions.md
  }
  filter {
    name   = "template"
    values = [true]
  }

  # Without this, a missing/renamed template fails on vms[0] with an
  # index-out-of-range error naming neither the template nor the cause.
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

  # Restated explicitly rather than relied on as clone inheritance — the
  # provider's clone guide isn't fully specific about what inherits, and a
  # documented issue exists where a full clone dropped source config. Matches
  # packer/windows-server-2025.pkr.hcl's source block exactly.
  machine = "q35"
  bios    = "ovmf"

  # "4m" is required for Secure Boot (provider default is "2m"); pre_enrolled_keys
  # defaults to false. Neither inherits from the template, so both are set
  # explicitly here on every UEFI guest (bpg/proxmox 0.112.0 docs).
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
    enabled = true # unlike OPNsense, this image has qemu-guest-agent installed.
  }

  disk {
    datastore_id = var.guest_datastore
    interface    = "scsi0"
    size         = 80 # matches the template's own disk size in packer/windows-server-2025.pkr.hcl.
  }

  network_device {
    bridge      = var.proxmox_bridge_trunk
    vlan_id     = var.network_vlan_servers
    mac_address = "02:00:00:00:00:C9" # docs/conventions.md — VMID 201.
  }

  # Terraform's last act: bring the guest up, then hand off to powershell/
  # (never AD commands inline — terraform-proxmox skill). Host is DC01's
  # DHCP-reservation address, its only address until first boot makes it
  # static (opnsense/dhcp.tf task 3).
  #
  # https=false + use_ntlm=true: the template has no cert for HTTPS, but NTLM
  # still encrypts the payload on port 5985 — setting only one of the two would
  # send the password across base64-encoded but unencrypted.
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

  # SafeModeAdminPassword is DC01-only — SRV01/CL01 have no forest to
  # recover, so neither invocation takes this argument.
  provisioner "remote-exec" {
    inline = [
      "powershell -ExecutionPolicy Bypass -File C:/lab-provisioning/Bootstrap-DC01.ps1 -LocalAdminPassword '${local.ps_local_admin_password}' -DomainAdminPassword '${local.ps_domain_admin_password}' -SafeModeAdminPassword '${local.ps_dsrm_recovery_password}'",
    ]
  }
}
