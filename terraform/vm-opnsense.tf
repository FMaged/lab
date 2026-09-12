# Boots the OPNsense installer ISO rather than cloning a template — there is no
# Packer image for it (packer-windows skill). Bootstrapped by hand after this
# VM exists (PLAN.md, runbook 3a).
resource "proxmox_virtual_environment_vm" "opnsense" {
  name      = "opnsense"
  node_name = var.proxmox_node
  vm_id     = 101 # docs/conventions.md — Management VLAN (10), sequence 1.
  tags      = ["lab", "role-firewall"]

  cpu {
    cores = 2
  }

  memory {
    dedicated = 4096 # docs/hardware.md's per-guest RAM split.
  }

  # OPNsense (FreeBSD) has no qemu-guest-agent installed by default. Leaving
  # this enabled would make Proxmox wait on a ping that never arrives.
  agent {
    enabled = false
  }

  operating_system {
    type = "l26" # closest available type; the provider has no FreeBSD/BSD option.
  }

  cdrom {
    file_id = "${var.iso_datastore}:iso/opnsense.iso"
  }

  disk {
    datastore_id = var.guest_datastore
    interface    = "scsi0"
    size         = 32
  }

  # WAN uplink — untagged, lands on the existing home network per
  # docs/network-design.md. Not part of the lab's own VLANs.
  network_device {
    bridge = var.proxmox_bridge_wan
  }

  # The VLAN trunk — deliberately no vlan_id, since OPNsense itself tags/untags
  # VLANs 10/20/30 on its side. The one documented exception in the
  # terraform-proxmox skill to "every network_device gets an explicit vlan_id" —
  # not a precedent for any other guest.
  network_device {
    bridge = var.proxmox_bridge_trunk
  }

  boot_order = ["ide2", "scsi0"]
}
