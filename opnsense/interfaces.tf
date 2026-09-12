# Creates the VLAN devices only — assigning each to a logical interface with a
# static address is manual (PLAN.md manual/code boundary; runbook 3a step 6).
resource "opnsense_interfaces_vlan" "management" {
  parent      = var.trunk_parent_interface
  tag         = var.network_vlan_management
  description = "Management VLAN — see docs/network-design.md"
}

resource "opnsense_interfaces_vlan" "servers" {
  parent      = var.trunk_parent_interface
  tag         = var.network_vlan_servers
  description = "Servers VLAN — DC01, SRV01"
}

resource "opnsense_interfaces_vlan" "clients" {
  parent      = var.trunk_parent_interface
  tag         = var.network_vlan_clients
  description = "Clients VLAN — CL01"
}
