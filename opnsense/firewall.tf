# Evaluation order matters in a filter chain — resources here are declared in
# the same order OPNsense evaluates them (ascending `sequence`), matching the
# rule table in docs/network-design.md exactly. Nothing here may contradict
# that table; if a rule needs to change, change the table first.

locals {
  management_subnet = "10.10.${var.network_vlan_management}.0/24"
  servers_subnet    = "10.10.${var.network_vlan_servers}.0/24"
  clients_subnet    = "10.10.${var.network_vlan_clients}.0/24"
}

# -- Aliases --

resource "opnsense_firewall_alias" "dc01" {
  name        = "dc01"
  type        = "host"
  content     = ["10.10.20.10"] # DC01's static address — see docs/network-design.md.
  description = "DC01 — see docs/network-design.md"
}

resource "opnsense_firewall_alias" "lab_networks" {
  name        = "lab_networks"
  type        = "network"
  content     = [local.management_subnet, local.servers_subnet, local.clients_subnet]
  description = "All three lab subnets — used by the single outbound NAT rule"
}

# -- Inter-VLAN: Clients to DC01, exactly what a domain member needs --
# DNS and Kerberos each need a TCP and a UDP rule; LDAP/SMB are TCP-only, NTP is
# UDP-only. Management is not a destination anywhere in this file, by omission
# — default-deny handles the rest, per the decision in PLAN.md.

resource "opnsense_firewall_filter" "clients_to_dc01_dns_tcp" {
  sequence    = 100
  description = "Clients to DC01 — DNS (name resolution)"
  interface   = { interface = [var.opnsense_interface_clients] }
  filter = {
    action      = "pass"
    direction   = "in"
    protocol    = "TCP"
    source      = { net = local.clients_subnet }
    destination = { net = opnsense_firewall_alias.dc01.name, port = "53" }
  }
}

resource "opnsense_firewall_filter" "clients_to_dc01_dns_udp" {
  sequence    = 101
  description = "Clients to DC01 — DNS (name resolution)"
  interface   = { interface = [var.opnsense_interface_clients] }
  filter = {
    action      = "pass"
    direction   = "in"
    protocol    = "UDP"
    source      = { net = local.clients_subnet }
    destination = { net = opnsense_firewall_alias.dc01.name, port = "53" }
  }
}

resource "opnsense_firewall_filter" "clients_to_dc01_kerberos_tcp" {
  sequence    = 102
  description = "Clients to DC01 — Kerberos (domain authentication)"
  interface   = { interface = [var.opnsense_interface_clients] }
  filter = {
    action      = "pass"
    direction   = "in"
    protocol    = "TCP"
    source      = { net = local.clients_subnet }
    destination = { net = opnsense_firewall_alias.dc01.name, port = "88" }
  }
}

resource "opnsense_firewall_filter" "clients_to_dc01_kerberos_udp" {
  sequence    = 103
  description = "Clients to DC01 — Kerberos (domain authentication)"
  interface   = { interface = [var.opnsense_interface_clients] }
  filter = {
    action      = "pass"
    direction   = "in"
    protocol    = "UDP"
    source      = { net = local.clients_subnet }
    destination = { net = opnsense_firewall_alias.dc01.name, port = "88" }
  }
}

resource "opnsense_firewall_filter" "clients_to_dc01_ldap" {
  sequence    = 104
  description = "Clients to DC01 — LDAP (directory queries, GPO lookup)"
  interface   = { interface = [var.opnsense_interface_clients] }
  filter = {
    action      = "pass"
    direction   = "in"
    protocol    = "TCP"
    source      = { net = local.clients_subnet }
    destination = { net = opnsense_firewall_alias.dc01.name, port = "389" }
  }
}

resource "opnsense_firewall_filter" "clients_to_dc01_smb" {
  sequence    = 105
  description = "Clients to DC01 — SMB (SYSVOL/NETLOGON, GPO and script delivery)"
  interface   = { interface = [var.opnsense_interface_clients] }
  filter = {
    action      = "pass"
    direction   = "in"
    protocol    = "TCP"
    source      = { net = local.clients_subnet }
    destination = { net = opnsense_firewall_alias.dc01.name, port = "445" }
  }
}

resource "opnsense_firewall_filter" "clients_to_dc01_ntp" {
  sequence    = 106
  description = "Clients to DC01 — NTP (Kerberos needs a small clock skew)"
  interface   = { interface = [var.opnsense_interface_clients] }
  filter = {
    action      = "pass"
    direction   = "in"
    protocol    = "UDP"
    source      = { net = local.clients_subnet }
    destination = { net = opnsense_firewall_alias.dc01.name, port = "123" }
  }
}

# -- Outbound to the internet, one rule per VLAN --
# Clients get no direct outbound DNS/NTP rule — see the DNS section in
# docs/network-design.md; both go through DC01 instead.

resource "opnsense_firewall_filter" "management_outbound_web" {
  sequence    = 200
  description = "Management outbound — Proxmox/OPNsense package and firmware updates"
  interface   = { interface = [var.opnsense_interface_management] }
  filter = {
    action      = "pass"
    direction   = "in"
    protocol    = "TCP"
    source      = { net = local.management_subnet }
    destination = { net = "any", port = "80" }
  }
}

resource "opnsense_firewall_filter" "management_outbound_web_tls" {
  sequence    = 201
  description = "Management outbound — Proxmox/OPNsense package and firmware updates"
  interface   = { interface = [var.opnsense_interface_management] }
  filter = {
    action      = "pass"
    direction   = "in"
    protocol    = "TCP"
    source      = { net = local.management_subnet }
    destination = { net = "any", port = "443" }
  }
}

resource "opnsense_firewall_filter" "servers_outbound_dns" {
  sequence    = 202
  description = "Servers outbound — DC01's forwarder resolves through here"
  interface   = { interface = [var.opnsense_interface_servers] }
  filter = {
    action      = "pass"
    direction   = "in"
    protocol    = "UDP"
    source      = { net = local.servers_subnet }
    destination = { net = "any", port = "53" }
  }
}

resource "opnsense_firewall_filter" "servers_outbound_web" {
  sequence    = 203
  description = "Servers outbound — Windows Update, package sources"
  interface   = { interface = [var.opnsense_interface_servers] }
  filter = {
    action      = "pass"
    direction   = "in"
    protocol    = "TCP"
    source      = { net = local.servers_subnet }
    destination = { net = "any", port = "443" }
  }
}

resource "opnsense_firewall_filter" "servers_outbound_ntp" {
  sequence    = 204
  description = "Servers outbound — DC01 is the domain's authoritative time source"
  interface   = { interface = [var.opnsense_interface_servers] }
  filter = {
    action      = "pass"
    direction   = "in"
    protocol    = "UDP"
    source      = { net = local.servers_subnet }
    destination = { net = "any", port = "123" }
  }
}

resource "opnsense_firewall_filter" "clients_outbound_web" {
  sequence    = 205
  description = "Clients outbound — Windows Update, general use"
  interface   = { interface = [var.opnsense_interface_clients] }
  filter = {
    action      = "pass"
    direction   = "in"
    protocol    = "TCP"
    source      = { net = local.clients_subnet }
    destination = { net = "any", port = "443" }
  }
}

# -- Outbound NAT --
# One rule, all three lab subnets, translated to the WAN interface's address.
# No per-VLAN NAT rule — the filter rules above already scope what reaches WAN.

resource "opnsense_firewall_nat" "outbound" {
  interface   = "wan"
  protocol    = "any"
  description = "Masquerade all lab subnets behind the WAN address"
  source = {
    net = opnsense_firewall_alias.lab_networks.name
  }
  target = {
    ip = "wanip"
  }
}
