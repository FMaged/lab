# Kea serves two VLANs, for two different reasons — see the bootstrap addressing
# decision in PLAN.md. Kea is subnet-based, not tied to an interface resource
# directly; whether OPNsense also needs a manual per-interface "enable Kea here"
# toggle beyond this is unconfirmed — flag it at the proof run if so, same as the
# other residual unknowns in this project.

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

# Deliberately no `pools` — this is a reservation-only scope. An unknown MAC on
# the Servers VLAN gets nothing at all, which is the point: DC01 and SRV01 exist
# here only long enough for Terraform's WinRM handoff, after which PowerShell
# makes the address static. A pool here would be a bug, not a convenience.
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
