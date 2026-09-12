# SI Portfolio Lab

[![Validate](https://github.com/FMaged/lab/actions/workflows/validate.yml/badge.svg)](https://github.com/FMaged/lab/actions/workflows/validate.yml)

A small company network defined entirely as code — a Proxmox hypervisor, Windows
Server 2025 and Windows 11 images, a routed multi-VLAN network and an Active Directory
domain — written so it can be built and torn down from this repository alone.

It exists to demonstrate Systemintegration skills: hypervisor administration,
infrastructure as code, Windows Server and Active Directory administration, and network
and firewall configuration. Every layer is written out in full and checked on every
push. None of it has been applied to hardware — see [Execution
status](#execution-status) for exactly what is and is not proven.

## Architecture

```mermaid
flowchart TB
    internet(("Internet")) --- home["Home router<br/>192.168.1.0/24"]
    home -- WAN --- opn["OPNsense"]
    opn -- VLAN 10 Mgmt --- proxmox["Proxmox host"]
    opn -- VLAN 20 Servers --- dc01["DC01"]
    opn -- VLAN 20 Servers --- srv01["SRV01"]
    opn -- VLAN 30 Clients --- cl01["CL01"]
```

Full diagram with addressing: [docs/network-diagram.md](docs/network-diagram.md).

## Where to start reading

1. [docs/walkthrough.md](docs/walkthrough.md) — **start here.** One machine, from
   blank installation media to a domain member with a policy applied, naming the file
   responsible at each step.
2. [docs/network-design.md](docs/network-design.md) and
   [docs/network-diagram.md](docs/network-diagram.md) — VLANs, addressing, DHCP, DNS
   and the firewall policy.
3. [docs/ad-design.md](docs/ad-design.md) — the domain: OUs, groups, GPOs.
4. [docs/conventions.md](docs/conventions.md) — naming, VM IDs, MACs, template and ISO
   names, and the branch and commit rules.
5. [docs/hardware.md](docs/hardware.md) — what a host would need to run this.
6. [docs/runbook.md](docs/runbook.md) — bare metal to a working domain, in order.
7. [PLAN.md](PLAN.md) — the goal, the stack, and why each major choice was made,
   including the options that were rejected.
8. [TASKS.md](TASKS.md) — current progress, milestone by milestone.

## Layer index

| Layer | What it does |
| --- | --- |
| [packer/](packer/) | Builds the two base images — Windows Server 2025 and Windows 11 |
| [terraform/](terraform/) | Creates all four VMs on Proxmox: the three Windows guests cloned from those images, plus the OPNsense firewall booted from its installer ISO |
| [powershell/](powershell/) | First-boot config: identity, AD promotion, domain join, GPOs, and a read-only health check |
| [opnsense/](opnsense/) | VLAN interfaces, DHCP, firewall rules and NAT for the lab |

## Execution status

**This lab has not been applied to real hardware.** No Proxmox host exists yet, and
the development machine can't stand in for one — see the execution-status decision
in [PLAN.md](PLAN.md). Every claim below is about what's checked, not what's run.

What the green badge above actually means, on every push:

| Layer | Checked by CI |
| --- | --- |
| `terraform/`, `opnsense/` | `terraform fmt -check` and `terraform validate` |
| `packer/` | `packer fmt -check` and `packer validate` |
| `powershell/` | PSScriptAnalyzer, failing on Error and Warning |
| whole repo | gitleaks secret scan, markdown link check |

This catches malformed code, bad references and leaked secrets — it does not prove
a VM boots, a domain forms, or a firewall rule actually blocks anything. That proof
is Milestone 8: an optional run on rented bare metal, captured as evidence. See
[TASKS.md](TASKS.md) for what's done and what's next; this section's wording
updates the moment a real proof run lands.

## Scope — what this deliberately does not do

Each of these is a decision, not an omission. The reasoning is in
[PLAN.md](PLAN.md); this is the short version.

| Left out | Why |
| --- | --- |
| High availability, clustering, failover | One host, one site. Redundancy would add machinery without demonstrating anything the single-site design does not. |
| Backup, monitoring, log aggregation | Each is a project of its own. Adding a half-built one would say less than leaving it out deliberately. |
| Cloud and hybrid identity | No Entra ID, no directory sync. The point is the on-premises fundamentals. |
| Image generalization (sysprep) | The clones share a machine SID, which is harmless because domain join issues a fresh machine account. The tradeoff is written up in full in PLAN.md. |
| A second domain controller | Replication is worth showing, but not at the cost of the client that proves a policy actually reaches a workstation. |
| Any of it running | No Proxmox host exists. See [Execution status](#execution-status) above. |

## What would come next

1. **The proof run.** Rent bare metal by the hour, apply the whole repository once,
   capture the evidence, destroy it. Planned as Milestone 8 in [TASKS.md](TASKS.md)
   and deliberately optional — everything before it stands on its own.
2. **A second domain controller.** Replication and DNS redundancy, once there is a
   host with room for a fifth VM.
3. **Backup and monitoring**, in that order. Backup first, because a lab that cannot
   be restored teaches the wrong habit.
