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

## Build network (Packer only)

A fourth, disposable network, `10.10.99.0/24` on `vmbr2` — not a VLAN, not tagged,
and not part of the lab's own topology above. It exists only because `packer build`
needs somewhere to put a build VM before OPNsense exists to route anything, and is
torn down conceptually the moment the templates it built are done — nothing in
production ever attaches to it. `scripts/host-runner.sh` creates `vmbr2` at
`10.10.99.1` and serves DHCP on it with `dnsmasq`, pool `10.10.99.100`–`10.10.99.200`.
OPNsense's build VM, which has no guest agent to be addressed by, gets a fixed
reservation outside that pool at `10.10.99.10` — see the host-network SPIKE decision
in `PLAN.md` and `packer/opnsense.pkr.hcl`. `scripts/host-runner.sh` also creates
`vmbr1` (the VLAN 10/20/30 trunk) and the host's own `10.10.10.2` on it, once the
firewall rules in the Firewall policy section below allow that address through.

## Static address table

| Host | VLAN | Address | Notes |
| --- | --- | --- | --- |
| OPNsense (WAN) | — | DHCP from 192.168.1.0/24 | uplink only |
| OPNsense (Mgmt) | 10 | 10.10.10.1 | gateway for VLAN 10 |
| OPNsense (Servers) | 20 | 10.10.20.1 | gateway for VLAN 20 |
| OPNsense (Clients) | 30 | 10.10.30.1 | gateway for VLAN 30 |
| Proxmox host | 10 | 10.10.10.2 | web UI + API — reaches the provider's uplink by DHCP first (install time, no VLANs exist yet), then the host-side runner creates `vmbr1` and this address itself — see below |
| DC01 | 20 | 10.10.20.10 | reaches this address by DHCP reservation first, then PowerShell sets it statically — see below |
| SRV01 | 20 | 10.10.20.11 | same bootstrap-then-static path as DC01 |
| CL01 | 30 | 10.10.30.50 | DHCP reservation, mandatory — CL01 stays on DHCP permanently, this just pins the lease |

The Proxmox host's own address arrives in two stages, not one — the same
bootstrap-then-static shape DC01 and SRV01 use, but for the host itself rather
than a guest. `proxmox/answer.toml` installs the host with `source = "from-dhcp"`:
whatever the rented server's provider hands out on its single physical NIC, since
no VLAN exists yet to put a static address on. Only once the build has run and
`vmbr1` (the VLAN trunk bridge) exists does the host-side runner add `10.10.10.2`
as a tagged address on VLAN 10 — see the host-network SPIKE decision in `PLAN.md`.

## DHCP

OPNsense serves Kea DHCP on two VLANs, for two different reasons:

- **Clients (30)** has a real pool, `10.10.30.100`–`10.10.30.200`, plus a mandatory
  reservation for CL01 at `10.10.30.50` (outside the pool, so it can never be handed
  to anything else). CL01 stays on DHCP for the life of the lab — the reservation
  only exists so its address is as stable as if it were static.
- **Servers (20)** has reservations for DC01 and SRV01 and **no dynamic pool at
  all**. This is deliberate, not an unfinished scope: an unknown MAC on this VLAN
  gets nothing, so the reservation list is the only way onto it. See the bootstrap
  addressing decision in PLAN.md for why a "static" VLAN runs DHCP at all — a
  freshly cloned guest has no address until something gives it one, and Terraform
  needs to reach it over WinRM before PowerShell can set anything.

**Management (10)** still gets no DHCP scope of any kind — Proxmox and OPNsense's
own management addresses are configured directly, never through this mechanism.

The DHCP reservation is a bootstrap crutch for DC01 and SRV01, not their running
state: PowerShell writes the same address statically at first boot, because a
domain controller must not depend on DHCP responding after a reboot. CL01 is the
opposite — DHCP is its permanent mechanism, the reservation just removes the
"which address did it get this time" variable.

## DNS

DC01 runs AD-integrated DNS and is authoritative for `ad.silab.internal` (see
`docs/ad-design.md`). Its forwarder points at OPNsense's resolver
(`10.10.10.1`/`10.10.20.1`/`10.10.30.1`, whichever is closer), which resolves the
public internet through the WAN uplink. Every VM's DNS server is DC01, but the
mechanism differs by how the VM gets its address: DC01 and SRV01 are static, so
PowerShell sets DNS explicitly at first boot. CL01 is DHCP, so it gets DNS from
the Kea scope's `dns_servers` option instead (`opnsense/dhcp.tf`) — deliberately
configured to hand out `10.10.20.10`, not left on whatever OPNsense would offer
by default.

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
inbound from any other VLAN.** Neither SRV01 nor CL01 is a destination for
*another VLAN's* traffic here — only the Proxmox host's own provisioning
traffic reaches either directly, below.

**Provisioning — the Proxmox host to specific lab guests, and to OPNsense's own
API.** The build now runs on the host itself (Milestone 10), so `10.10.10.2` is
the source Terraform's WinRM handoff and the host-side runner's health check
both come from, and the source `opnsense/`'s own Terraform provider calls the
firewall's API from. Each rule names the host as its only source and one guest
or the firewall itself as its only destination — never the whole Management
subnet, the way the outbound-to-internet table below does:

| Source | Destination | Service | Port | Reason |
| --- | --- | --- | --- | --- |
| Proxmox host (10.10.10.2) | OPNsense (10.10.10.1) | HTTPS | 443/tcp | `opnsense/`'s own Terraform provider — its API calls are traffic like any other, not exempt from the empty default-deny ruleset |
| Proxmox host (10.10.10.2) | DC01 (10.10.20.10) | WinRM | 5985/tcp | Terraform's provisioner, and the runner polling `phase.json` / running the health check |
| Proxmox host (10.10.10.2) | SRV01 (10.10.20.11) | WinRM | 5985/tcp | same as DC01 |
| Proxmox host (10.10.10.2) | CL01 (10.10.30.50) | WinRM | 5985/tcp | same as DC01 |

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
