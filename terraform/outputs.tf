# Addresses are literals matching docs/network-design.md, not read from a
# Terraform-managed ip_config block (none of these guests have one). None of
# these four outputs need `sensitive = true` either — no credential in them.

output "opnsense" {
  value = {
    name    = proxmox_virtual_environment_vm.opnsense.name
    address = "10.10.10.1" # Management VLAN — see docs/network-design.md.
    vm_id   = proxmox_virtual_environment_vm.opnsense.vm_id
  }
}

output "dc01" {
  value = {
    name    = proxmox_virtual_environment_vm.dc01.name
    address = "10.10.20.10"
    vm_id   = proxmox_virtual_environment_vm.dc01.vm_id
  }
}

output "srv01" {
  value = {
    name    = proxmox_virtual_environment_vm.srv01.name
    address = "10.10.20.11"
    vm_id   = proxmox_virtual_environment_vm.srv01.vm_id
  }
}

output "cl01" {
  value = {
    name    = proxmox_virtual_environment_vm.cl01.name
    address = "10.10.30.50" # DHCP reservation, not static — see docs/network-design.md.
    vm_id   = proxmox_virtual_environment_vm.cl01.vm_id
  }
}
