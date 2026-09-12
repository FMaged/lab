# Hardware — the Proxmox host

No host exists, and buying one is not the plan. This is what a machine would need to
run the lab, whether owned or rented by the hour for a proof run — see the proof run
decision in [PLAN.md](../PLAN.md). Nothing below is an outstanding decision; both NIC
layouts stay valid and the choice is made by whatever machine is actually used.

## Target spec

| Component | Target | Why |
| --- | --- | --- |
| CPU | 4+ cores / 8+ threads, VT-x/AMD-V | Four guests running concurrently (OPNsense, DC01, SRV01, CL01), none of them CPU-heavy |
| RAM | 32 GB | ~4 GB OPNsense, 8 GB DC01, 4 GB SRV01, 4 GB CL01, leaves headroom for Proxmox itself and ZFS ARC if used |
| Storage | 500 GB+ NVMe SSD | Four thin-provisioned Windows/BSD disks plus the Packer template; NVMe keeps Windows install and clone time reasonable |
| Network | 2 NICs (or 1 NIC + a VLAN-capable managed switch) | OPNsense needs a WAN port separate from the VLAN trunk; see below |

This is enough for four guests with room to spare — it is not sized for load, since
nothing here serves real traffic.

## Network topology at the host

Two viable NIC layouts, either is fine:

- **Two physical NICs**: one dedicated to OPNsense's WAN (plugged into the existing
  192.168.1.0/24 home network), one as an 802.1Q trunk carrying VLANs 10/20/30 to a
  Proxmox Linux bridge, which OPNsense and every VM's virtual NIC attach to.
- **One physical NIC**: the switch port it lands on must itself be a VLAN trunk, with
  the home network reachable as one more tagged (or the native/untagged) VLAN on that
  same trunk.

Either way, the Proxmox management interface (10.10.10.2, VLAN 10) must be reachable
without going through OPNsense, or a misconfigured firewall rule locks out the only
way to fix it.

## Pre-install checklist

- VT-x/AMD-V (or equivalent) enabled in firmware — required for any VM to boot at all.
- UEFI boot enabled, CSM/legacy boot off — matches how both Packer builds expect their
  templates' boot mode to be created, and Windows 11 additionally requires it.
- Confirm the NIC(s) support VLAN tagging end to end: NIC driver, and — if using the
  two-NIC layout — the switch port(s) they land on.
- Confirm the switch port for the trunk NIC is actually configured as a trunk before
  first boot; VLAN 20 (Servers) being unreachable is what silent trunk misconfiguration
  looks like from inside a guest.

## On rented bare metal

The proof run in `TASKS.md` targets an hourly-billed bare metal machine rather than a
box in a cupboard, and two assumptions above do not survive that move:

- **There is no home router.** The WAN uplink becomes the provider's network with a
  public address, not a DHCP lease from `192.168.1.0/24`. Everything below WAN is
  unaffected — the three lab VLANs are private and self-contained — but OPNsense's WAN
  interface, and any firewall rule that names the home network, has to be read as "the
  uplink" rather than that specific subnet.
- **There is usually one NIC and no switch you control.** That forces the single-NIC
  layout above, with the lab VLANs living entirely on an internal Proxmox bridge that
  never leaves the host. This is simpler than the two-NIC case, not harder: no physical
  trunk to misconfigure.

Exposing a firewall's WAN interface directly to the public internet also makes the
default-deny posture in `network-design.md` load-bearing rather than decorative. Confirm
it before the machine is reachable, not after.
