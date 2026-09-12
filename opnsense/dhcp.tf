# DHCP only on the Clients VLAN — Management and Servers are static and listed
# in docs/network-design.md's address table. Kea is subnet-based, not tied to
# an interface resource directly; whether OPNsense also needs a manual
# per-interface "enable Kea here" toggle beyond this is unconfirmed — flag it
# at the proof run if so, same as the other residual unknowns in this project.
resource "opnsense_kea_dhcpv4_subnet" "clients" {
  subnet             = "10.10.30.0/24"
  description        = "Clients VLAN — CL01 and any future workstation"
  pools              = ["10.10.30.100-10.10.30.200"]
  routers            = ["10.10.30.1"]
  dns_servers        = ["10.10.20.10"] # DC01 — see the DNS section in docs/network-design.md.
  this_is_not_a_real_argument = true # deliberate break for task 10's CI-catches-it test
}
