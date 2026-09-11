# Tasks

<!--
[ ] open   [x] done   [~] dropped (add a one-line reason)
Do not rewrite a task after work on it started. Add new tasks at the end.
If the work went differently than planned, write it under Notes:
-->

## Milestone 1: The whole build is designed and readable from the repo alone

No Proxmox hardware yet, so this milestone produces the design and the entry point.
Someone who opens the repo can see what gets built, on what addresses, in what order.

- [x] Initialize the repository
  **What:** a git repo with a .gitignore covering Terraform state/plan files, Packer output
  directories and tfvars, plus a LICENSE and a repo description.
  **Why:** every other task writes files into this repo from here on, and secrets (tfvars)
  and generated build artifacts must never land in git — that has to be true from the
  first commit, not retrofitted later.
  **How:** git init; .gitignore entries for terraform.tfstate*, .terraform/, Packer output
  dirs and *.auto.tfvars; add a LICENSE; set the repo description.
  - [x] git init, .gitignore for Terraform state, Packer output and tfvars
  - [x] LICENSE and a repo description
  Notes: main branch, MIT license. Repo description deferred — no GitHub remote yet;
  set it when the repo is first pushed.

- [x] Create the directory layout with a stub README in each layer
  **What:** top-level folders packer/, terraform/, powershell/, opnsense/, docs/, each with
  a short README stating what will live there.
  **Why:** the repo layout is the first thing a reviewer sees before any code exists — it
  has to communicate the four-layer architecture on its own.
  **How:** mkdir the five directories, drop a one-paragraph README.md in each.
  - [x] packer/, terraform/, powershell/, opnsense/, docs/
  Notes:

- [x] Write docs/network-design.md
  **What:** VLAN list and purpose, subnet and gateway per VLAN, a static address table for
  DC01/SRV01/firewall interfaces, and DHCP scopes/reservations/options with DNS
  forwarders.
  **Why:** this is the single source of truth every other layer has to agree with —
  Terraform's static IPs, the OPNsense config, and the PowerShell provisioning all read
  from these addresses, so it has to exist before any of them are written.
  **How:** one markdown table per VLAN (purpose, subnet, gateway), one static-address
  table, one section for DHCP scopes/reservations/options and DNS forwarders.
  - [x] VLAN list and purpose, subnet per VLAN, gateway addresses
  - [x] Static address table for DC01, SRV01 and the firewall interfaces
  - [x] DHCP scopes, reservations and options, DNS forwarders
  Notes: 3 VLANs (10 Mgmt / 20 Servers / 30 Clients), 10.10.x.0/24, chosen to sit
  clear of the existing 192.168.1.0/24 home network per user. DHCP only on the
  Clients VLAN — Mgmt and Servers are static and listed in the table.

- [x] Write docs/ad-design.md
  **What:** forest and domain name, functional level, site name, OU structure with the
  reasoning behind its shape, groups, and the three baseline GPOs with what each one
  enforces.
  **Why:** Milestone 5's PowerShell promotes DC01 and applies this structure directly —
  writing the design now means that script implements a spec instead of ad-hoc
  decisions made while coding.
  **How:** one section per topic; OU structure gets a short paragraph justifying its
  shape; each GPO gets a one-line "what it enforces and why".
  - [x] Forest and domain, functional level, site name
  - [x] OU structure and the reasoning behind its shape
  - [x] Groups and the three baseline GPOs, each with what it enforces and why
  Notes: functional level 2025 (no legacy DC to support). Workstation GPO's logon
  banner chosen deliberately as the visible proof-point for Milestone 6.

- [x] Draw the network diagram as Mermaid in docs/
  **What:** a Mermaid diagram showing the VLANs, the firewall, and where DC01/SRV01/CL01
  sit on the network.
  **Why:** the README links to one diagram as the fastest way for a reviewer to grasp the
  topology — the address tables in network-design.md don't give that at a glance.
  **How:** a Mermaid graph/flowchart block in docs/, matching the addresses and VLANs
  already written in network-design.md.
  Notes:

- [x] Write docs/hardware.md — the Proxmox host
  **What:** the target Proxmox host spec and the UEFI/virtualization/NIC prerequisites to
  verify before install.
  **Why:** Milestone 2 needs the hardware bought and installed correctly on the first
  attempt — there's no lab access yet to iterate on a wrong spec.
  **How:** list CPU/RAM/disk/NIC targets and why they're enough for four guests, plus a
  pre-install checklist (VT-x/AMD-V enabled, UEFI boot, NIC passthrough support).
  - [x] Target spec and why it is enough for four guests
  - [x] UEFI, virtualization and NIC prerequisites to check before install
  Notes: documented both single-NIC and dual-NIC trunk layouts since the actual host
  isn't bought yet — narrow to one once hardware is chosen.

- [x] Write docs/conventions.md
  **What:** the VM and hostname naming scheme, Terraform resource/variable naming, VM
  tags, and branch/commit conventions.
  **Why:** Terraform, PowerShell and git history all need to follow one scheme
  consistently from the first resource — renaming later means touching every layer
  that references it.
  **How:** short reference tables for hostname pattern, Terraform naming pattern and tag
  list, plus a pointer to the git-conventions skill for branch/commit format.
  - [x] VM and hostname scheme, Terraform resource and variable naming, VM tags
  - [x] Branch and commit conventions
  Notes: branch/commit section just points at the global git-conventions skill and
  fixes no-ref as the default (solo project, no ticket tracker).

- [x] Write docs/runbook.md as a skeleton
  **What:** bare metal to a working domain, ordered, with a placeholder section per layer
  to fill in as each milestone lands.
  **Why:** this is the proof that the whole lab "rebuilds from zero in one documented
  pass" (Milestone 7) — it has to exist from the start so each milestone adds to it as
  it's built, instead of being reconstructed from memory at the end.
  **How:** one heading per milestone in build order, each with a one-line placeholder.
  Notes:

- [x] Write the top-level README.md
  **What:** what this lab demonstrates, the architecture in one diagram, and where to
  start reading.
  **Why:** per the goal in PLAN.md, this is the page the reviewer actually opens — success
  is them understanding what was built and why within five minutes of landing here.
  **How:** short intro, embed/link the Mermaid diagram, links to docs/*.md in reading
  order, link to the runbook.
  Notes:

- [ ] SPIKE: how does OPNsense get configured as code (max 2h)
  **Why:** Milestone 4 needs a repeatable, version-controlled way to apply VLANs,
  interfaces, DHCP and firewall rules — picking the wrong mechanism now means redoing
  the whole opnsense/ layer later.
  **How:** compare config.xml import against the REST API for coverage of VLANs,
  interfaces, DHCP and firewall rules; note any plugin dependencies.
  Output: one decision entry in PLAN.md

- [ ] SPIKE: how do secrets reach Packer, Terraform and PowerShell (max 2h)
  **Why:** the domain administrator password, the Proxmox API token and the local admin
  password each need to reach a different tool, and none of them can land in git —
  the approach has to work for all three or the layers won't agree.
  **How:** compare .gitignored tfvars + env vars against a local secrets file and a
  secrets manager; check what Packer, Terraform and PowerShell can each consume
  natively.
  Output: one decision entry in PLAN.md

## Milestone 2: Proxmox host is installed and reachable as an automation target

<!-- Not planned yet. Needs hardware. -->

## Milestone 3: Packer produces a Windows Server 2025 template

<!-- Not planned yet. -->

## Milestone 4: OPNsense routes the lab VLANs

<!-- Not planned yet. -->

## Milestone 5: Terraform clones DC01 and PowerShell promotes it to a domain controller

<!-- Not planned yet. The PowerShell does not exist yet — it is written here, not reused. -->

## Milestone 6: SRV01 and CL01 join the domain and the baseline GPOs are seen applying

<!-- Not planned yet. -->

## Milestone 7: The whole lab rebuilds from zero in one documented pass

<!-- Not planned yet. -->
