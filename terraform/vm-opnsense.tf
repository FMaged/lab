# Clones tpl-opnsense-v1 — the config-importer bakes in interface assignment,
# VLAN devices and addressing at build time, so this VM boots already routing
# (PLAN.md's zero-touch decision). No provisioner: unlike the Windows guests,
# nothing here needs a post-boot handoff — opnsense/'s Terraform root reaches
# it over the API the moment it answers, for DHCP, NAT and firewall rules.
data "proxmox_virtual_environment_vms" "opnsense_template" {
  filter {
    name   = "name"
    values = ["tpl-opnsense-v1"] # docs/conventions.md
  }
  filter {
    name   = "template"
    values = [true]
  }

  # See the comment in vm-dc01.tf.
  lifecycle {
    postcondition {
      condition     = length(self.vms) == 1
      error_message = "Expected exactly one Proxmox template named tpl-opnsense-v1 (docs/conventions.md). Run the Packer build in packer/ first, or check the template was not renamed."
    }
  }
}

resource "proxmox_virtual_environment_vm" "opnsense" {
  name      = "opnsense"
  node_name = var.proxmox_node
  vm_id     = 101 # docs/conventions.md — Management VLAN (10), sequence 1.
  tags      = ["lab", "role-firewall"]

  clone {
    vm_id = data.proxmox_virtual_environment_vms.opnsense_template.vms[0].vm_id
    full  = true
  }

  # Matches packer/opnsense.pkr.hcl's source block exactly — see the comment in
  # vm-dc01.tf on why this is restated rather than relied on as inheritance.
  # No EFI/TPM: OPNsense/FreeBSD needs neither.
  machine = "q35"
  bios    = "seabios"

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

  disk {
    datastore_id = var.guest_datastore
    interface    = "scsi0"
    size         = 32 # matches the template's own disk size in packer/opnsense.pkr.hcl.
  }

  # WAN uplink — untagged, lands on the existing home network per
  # docs/network-design.md. Not part of the lab's own VLANs. MAC from
  # docs/conventions.md; the trunk NIC below stays unpinned, same as before —
  # nothing reserves DHCP for OPNsense, so only one documented MAC per guest
  # is enough to satisfy the "every guest has one" convention.
  network_device {
    bridge      = var.proxmox_bridge_wan
    mac_address = "02:00:00:00:00:65"
  }

  # The VLAN trunk. Deliberately no vlan_id — the trunk carries VLANs 10/20/30
  # tagged, and the template's baked-in config.xml is what creates and
  # assigns the three VLAN devices on top of it, not opnsense/interfaces.tf
  # any more (PLAN.md's zero-touch decision; task 8 removed those resources).
  # The one documented exception in the terraform-proxmox skill to "every
  # network_device gets an explicit vlan_id" — not a precedent for any other
  # guest. Order matters: this must stay the second network_device, matching
  # the vtnet0/vtnet1 order packer/opnsense.pkr.hcl built the template with.
  network_device {
    bridge = var.proxmox_bridge_trunk
  }
}
