# The firewall VM. Boots the OPNsense installer ISO rather than cloning a
# template — there is no Packer image for it, per the packer-windows skill.
# Bootstrapped by hand after this VM exists; see the bootstrap decision in
# PLAN.md and runbook section 3a.
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

  # The VLAN trunk. Deliberately no vlan_id — this carries VLANs 10, 20 and 30
  # tagged, so OPNsense itself does the tagging/untagging on its side. This is
  # the one documented exception in the terraform-proxmox skill to "every
  # network_device gets an explicit vlan_id." Do not add one here, and do not
  # treat this as a precedent for any other guest.
  network_device {
    bridge = var.proxmox_bridge_trunk
  }

  boot_order = ["ide2", "scsi0"]
}
