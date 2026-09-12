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

# OPNsense's own key per assigned interface, not the VLAN ID — unconfirmed until
# runbook 3a step 6 actually assigns them; "opt1/opt2/opt3" is a guess, not verified.

variable "opnsense_interface_management" {
  type        = string
  description = "OPNsense's assigned-interface key for the Management VLAN — unconfirmed, see above"
  default     = "opt1"
}

variable "opnsense_interface_servers" {
  type        = string
  description = "OPNsense's assigned-interface key for the Servers VLAN — unconfirmed, see above"
  default     = "opt2"
}

variable "opnsense_interface_clients" {
  type        = string
  description = "OPNsense's assigned-interface key for the Clients VLAN — unconfirmed, see above"
  default     = "opt3"
}
