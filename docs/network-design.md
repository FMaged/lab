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

## Firewall policy

Default is deny between VLANs — an allow rule exists only for a specific, named
reason. This table is the spec `opnsense/firewall.tf` implements; a rule that
isn't in this table doesn't get written, and a row here with nothing implementing
it is a bug in that file, not a stricter-than-documented bonus.

**Inter-VLAN — Clients to DC01, exactly what a domain member needs:**

| Source | Destination | Service | Port | Reason |
| --- | --- | --- | --- | --- |
| Clients (10.10.30.0/24) | DC01 (10.10.20.10) | DNS | 53/tcp+udp | name resolution |
| Clients (10.10.30.0/24) | DC01 (10.10.20.10) | Kerberos | 88/tcp+udp | domain authentication |
| Clients (10.10.30.0/24) | DC01 (10.10.20.10) | LDAP | 389/tcp | directory queries, GPO lookup |
| Clients (10.10.30.0/24) | DC01 (10.10.20.10) | SMB | 445/tcp | SYSVOL/NETLOGON — GPO and script delivery |
| Clients (10.10.30.0/24) | DC01 (10.10.20.10) | NTP | 123/udp | time sync — Kerberos fails outside a small clock skew |

Nothing else crosses from Clients to Servers, and nothing from either reaches
Management: **Management (10.10.10.0/24) is the destination of zero rules,
inbound from any other VLAN.** SRV01 is deliberately not a destination here
either — nothing in this lab's topology needs to reach it directly yet.

**Outbound to the internet, one rule per VLAN, least privilege applied the same way:**

| Source | Service | Port | Reason |
| --- | --- | --- | --- |
| Management (10.10.10.0/24) | HTTP/HTTPS | 80,443/tcp | Proxmox and OPNsense package/firmware updates |
| Servers (10.10.20.0/24) | DNS | 53/tcp+udp | DC01's forwarder resolves through OPNsense, per the DNS section above |
| Servers (10.10.20.0/24) | HTTP/HTTPS | 80,443/tcp | Windows Update, package sources |
| Servers (10.10.20.0/24) | NTP | 123/udp | DC01 is the domain's authoritative time source and syncs it externally |
| Clients (10.10.30.0/24) | HTTP/HTTPS | 80,443/tcp | Windows Update, general use |

Clients get no outbound DNS or NTP rule — they resolve names and sync time
through DC01 (the inter-VLAN table above and AD's own time hierarchy), never
directly against the internet.

**NAT:** one outbound rule, masquerading all three lab subnets
(`10.10.10.0/24`, `10.10.20.0/24`, `10.10.30.0/24`) behind the WAN interface's
address. No per-VLAN NAT rule — the outbound allow rules above already scope
which traffic reaches WAN at all; NAT only has to translate it once it's there.
