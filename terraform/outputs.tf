# Addresses here are literals matching docs/network-design.md, not resource
# attributes — none of these VMs get their address from a Terraform-managed
# ip_config block, so there is nothing on the resource itself to read it from.
# No secrets: none of these four guests need one to be identified by.

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
