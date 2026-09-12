# Kea serves two VLANs for different reasons (PLAN.md bootstrap addressing) and is
# subnet-based, not interface-tied — unconfirmed whether OPNsense also needs a
# manual per-interface toggle; flag it at the proof run if so.

resource "opnsense_kea_dhcpv4_subnet" "clients" {
  subnet      = "10.10.30.0/24"
  description = "Clients VLAN — CL01 and any future workstation"
  pools       = ["10.10.30.100-10.10.30.200"]
  routers     = ["10.10.30.1"]
  dns_servers = ["10.10.20.10"] # DC01 — see the DNS section in docs/network-design.md.
}

resource "opnsense_kea_dhcpv4_reservation" "cl01" {
  subnet_id   = opnsense_kea_dhcpv4_subnet.clients.id
  ip_address  = "10.10.30.50"
  mac_address = "02:00:00:00:01:2d" # docs/conventions.md — VMID 301.
  hostname    = "CL01"
  description = "CL01 — mandatory reservation, not a static host; see docs/network-design.md"
}

# No `pools` — reservation-only, so an unknown MAC gets nothing. DC01/SRV01 only
# need this subnet until Terraform's WinRM handoff; PowerShell makes it static after.
resource "opnsense_kea_dhcpv4_subnet" "servers" {
  subnet      = "10.10.20.0/24"
  description = "Servers VLAN — reservation-only, no pool. See the bootstrap addressing decision in PLAN.md."
  routers     = ["10.10.20.1"]
  dns_servers = ["10.10.20.10"] # DC01 — self-referential on purpose, matches the DNS section in docs/network-design.md.
}

resource "opnsense_kea_dhcpv4_reservation" "dc01" {
  subnet_id   = opnsense_kea_dhcpv4_subnet.servers.id
  ip_address  = "10.10.20.10"
  mac_address = "02:00:00:00:00:c9" # docs/conventions.md — VMID 201.
  hostname    = "DC01"
  description = "DC01 — bootstrap only, PowerShell sets this statically at first boot"
}

resource "opnsense_kea_dhcpv4_reservation" "srv01" {
  subnet_id   = opnsense_kea_dhcpv4_subnet.servers.id
  ip_address  = "10.10.20.11"
  mac_address = "02:00:00:00:00:ca" # docs/conventions.md — VMID 202.
  hostname    = "SRV01"
  description = "SRV01 — bootstrap only, PowerShell sets this statically at first boot"
}
