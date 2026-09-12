# SI Portfolio Lab

[![Validate](https://github.com/FMaged/lab/actions/workflows/validate.yml/badge.svg)](https://github.com/FMaged/lab/actions/workflows/validate.yml)

A small company network built entirely as code — a Proxmox hypervisor, a Windows
Server 2025 image, a routed multi-VLAN network and Active Directory — that can be
torn down and rebuilt from this repository alone.

It exists to demonstrate Systemintegration skills: hypervisor administration,
infrastructure as code, Windows Server/AD administration, and network/firewall
configuration, each done for real rather than described.

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

1. [PLAN.md](PLAN.md) — the goal, the stack, and why each major choice was made.
2. [docs/network-design.md](docs/network-design.md) and
   [docs/network-diagram.md](docs/network-diagram.md) — the network.
3. [docs/ad-design.md](docs/ad-design.md) — the domain: OUs, groups, GPOs.
4. [docs/hardware.md](docs/hardware.md) — the physical host this runs on.
5. [docs/runbook.md](docs/runbook.md) — bare metal to a working domain, in order;
   this is the build log as each milestone lands.
6. [TASKS.md](TASKS.md) — current progress, milestone by milestone.

## Layer index

| Layer | What it does |
| --- | --- |
| [packer/](packer/) | Builds the Windows Server 2025 base image |
| [terraform/](terraform/) | Clones DC01, SRV01, CL01 from that image onto Proxmox |
| [powershell/](powershell/) | First-boot config: identity, AD promotion, domain join, GPOs |
| [opnsense/](opnsense/) | Router and firewall config for the lab VLANs |

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
