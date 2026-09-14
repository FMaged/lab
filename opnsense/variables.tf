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

# OPNsense's own key per assigned interface, not the VLAN ID — fixed by packer/files/config.xml.

variable "opnsense_interface_management" {
  type        = string
  description = "OPNsense's assigned-interface key for the Management VLAN — see packer/files/config.xml"
  default     = "opt1"
}

variable "opnsense_interface_servers" {
  type        = string
  description = "OPNsense's assigned-interface key for the Servers VLAN — see packer/files/config.xml"
  default     = "opt2"
}

variable "opnsense_interface_clients" {
  type        = string
  description = "OPNsense's assigned-interface key for the Clients VLAN — see packer/files/config.xml"
  default     = "opt3"
}
