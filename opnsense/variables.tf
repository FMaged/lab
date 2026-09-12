variable "trunk_parent_interface" {
  type        = string
  description = "The trunk NIC's OPNsense device name (e.g. vtnet1) that VLAN devices attach to — noted during the manual bootstrap, runbook section 3a step 3"
  default     = "vtnet1"
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
