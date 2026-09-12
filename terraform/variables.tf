variable "proxmox_node" {
  type        = string
  description = "Proxmox node name the guests are created on"
  default     = "pve" # placeholder — see the secrets/placeholder reasoning in packer/variables.pkr.hcl.
}

variable "iso_datastore" {
  type        = string
  description = "Datastore holding the OPNsense installation ISO"
  default     = "local"
}

variable "guest_datastore" {
  type        = string
  description = "Datastore for guest disks"
  default     = "local-lvm"
}

variable "network_vlan_management" {
  type        = number
  description = "VLAN ID for the Management network — see docs/network-design.md"
  default     = 10
}

variable "network_vlan_servers" {
  type        = number
  description = "VLAN ID for the Servers network — see docs/network-design.md"
  default     = 20
}

variable "network_vlan_clients" {
  type        = number
  description = "VLAN ID for the Clients network — see docs/network-design.md"
  default     = 30
}
