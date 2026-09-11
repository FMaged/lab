# SI Portfolio Lab

A small company network — Proxmox host, Windows Server 2025 image, VMs, Active
Directory and a routed multi-VLAN network — built entirely as code and rebuildable
from this repo.

## Start here

- `PLAN.md` — goal, stack, and every decision with its reasoning. Read it before
  proposing anything architectural. If a decision there rejected an option, it stays
  rejected until the entry is replaced.
- `TASKS.md` — milestones and open work. Work comes from the current milestone only;
  later milestones are deliberately empty until the one before them lands.
- `docs/` — the design the code implements.

## Layout

| Path | What lives here |
| --- | --- |
| `packer/` | Windows Server 2025 base image build |
| `terraform/` | VM provisioning against Proxmox (bpg/proxmox) |
| `powershell/` | First-boot OS config, AD promotion, domain join, GPOs |
| `opnsense/` | Router and firewall config (Terraform, browningluke/opnsense provider) |
| `docs/` | Network and AD design, hardware, conventions, runbook |

## Conventions

- `docs/network-design.md` is the single source of truth for every address, VLAN and
  subnet. Terraform, the OPNsense config and PowerShell all have to agree with it —
  never hardcode an address that contradicts it; change the doc first.
- `docs/ad-design.md` is the spec that `powershell/` implements. Same rule.
- PowerShell is Windows PowerShell 5.1 only. The global `powershell` skill covers
  style; the rule on top of it here is that every script is idempotent — clones are
  provisioned by running them at first boot, and a failed run is retried, not
  hand-fixed.
- No secret lands in git: no passwords, no Proxmox API token, no tfvars. Secrets are
  env vars and gitignored local var files; PowerShell gets its secrets from
  Terraform's WinRM provisioner, never from a file on disk. See the decision in
  `PLAN.md`.
- Docs are a deliverable. A layer is not done until its section of `docs/runbook.md`
  is filled in.

## Working agreement

- Check tasks off in `TASKS.md` as they finish. If the work went differently than the
  task said, one line under `Notes:`.
- A new decision goes in `PLAN.md` as a decision entry — not in a commit message.
- Do not add a dependency, service or abstraction that no open task needs. Out of
  scope on purpose: HA, clustering, cloud/hybrid identity, monitoring, sysprep.
