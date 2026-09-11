# Network design

Three VLANs, routed by OPNsense, on hardware that is physically separate from the
existing 192.168.1.0/24 home network. OPNsense's WAN interface takes a DHCP lease
from the home router and NATs the lab out to the internet; everything below WAN is
new address space that cannot collide with anything already running.

## VLANs

| VLAN ID | Name | Purpose | Subnet | Gateway |
| --- | --- | --- | --- | --- |
| — | WAN | Uplink to the existing home network | 192.168.1.0/24 (DHCP-assigned) | home router |
| 10 | Management | Proxmox host and OPNsense's own management access | 10.10.10.0/24 | 10.10.10.1 |
| 20 | Servers | DC01, SRV01 | 10.10.20.0/24 | 10.10.20.1 |
| 30 | Clients | CL01 | 10.10.30.0/24 | 10.10.30.1 |

The Proxmox host's physical NIC is a trunk carrying VLANs 10/20/30; each VM's virtual
NIC is tagged to the one VLAN it belongs to (see the `terraform-proxmox` skill —
every `network_device` must set `vlan_id` explicitly). VLAN 1 is not used, so an
untagged frame has nowhere valid to go.

## Static address table

| Host | VLAN | Address | Notes |
| --- | --- | --- | --- |
| OPNsense (WAN) | — | DHCP from 192.168.1.0/24 | uplink only |
| OPNsense (Mgmt) | 10 | 10.10.10.1 | gateway for VLAN 10 |
| OPNsense (Servers) | 20 | 10.10.20.1 | gateway for VLAN 20 |
| OPNsense (Clients) | 30 | 10.10.30.1 | gateway for VLAN 30 |
| Proxmox host | 10 | 10.10.10.2 | web UI + API |
| DC01 | 20 | 10.10.20.10 | static — it is the DNS server, so it cannot get its own address from DHCP |
| SRV01 | 20 | 10.10.20.11 | static, same reason: a domain member server gets a stable address |
| CL01 | 30 | DHCP (reservation optional) | ordinary client; proves DHCP + domain join together |

## DHCP

OPNsense serves DHCP on VLAN 30 (Clients) only — pool `10.10.30.100`–`10.10.30.200`.
VLANs 10 and 20 have no DHCP scope: every host on them is known in advance and
listed in the static address table above, so DHCP there would only be a second place
for an address to drift out of sync with this document.

## DNS

DC01 runs AD-integrated DNS and is authoritative for `ad.silab.internal` (see
`docs/ad-design.md`). Its forwarder points at OPNsense's resolver
(`10.10.10.1`/`10.10.20.1`/`10.10.30.1`, whichever is closer), which resolves the
public internet through the WAN uplink. Every VM's DNS server is DC01 — set by
PowerShell at first boot, never left on a DHCP-supplied default.
