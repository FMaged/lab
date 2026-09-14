# No provisioner: the template's baked-in config.xml boots this VM already routing;
# opnsense/'s Terraform root reaches it over the API from there.
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

  # Restated, not relied on as inheritance — see the comment in vm-dc01.tf. No EFI/TPM: FreeBSD needs neither.
  machine = "q35"
  bios    = "seabios"

  cpu {
    cores = 2
  }

  memory {
    dedicated = 4096 # docs/hardware.md's per-guest RAM split.
  }

  # No qemu-guest-agent on FreeBSD; leaving this enabled would make Proxmox wait on a ping that never arrives.
  agent {
    enabled = false
  }

  disk {
    datastore_id = var.guest_datastore
    interface    = "scsi0"
    size         = 32 # matches the template's own disk size in packer/opnsense.pkr.hcl.
  }

  # WAN uplink — untagged, lands on the existing home network, not the lab's own VLANs.
  network_device {
    bridge      = var.proxmox_bridge_wan
    mac_address = "02:00:00:00:00:65"
  }

  # The VLAN trunk. No vlan_id: the template's baked-in config.xml creates and assigns the three
  # VLAN devices on top of it. Order matters — must stay second, matching opnsense.pkr.hcl's vtnet0/vtnet1.
  network_device {
    bridge = var.proxmox_bridge_trunk
  }
}
