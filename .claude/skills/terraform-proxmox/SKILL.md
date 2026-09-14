---
name: terraform-proxmox
description: Conventions for this repo's Terraform against Proxmox with the bpg/proxmox provider — layout under terraform/, cloning DC01/SRV01/CL01 from the Packer templates, VLAN-tagged NICs, static addressing taken from docs/network-design.md, and the handoff to first-boot PowerShell. Use when writing or changing anything under terraform/, when the user mentions Terraform, .tf files, tfvars, terraform plan or apply, the bpg provider, or provisioning a lab VM. Not for building the base image (see packer-windows) and not for OPNsense configuration.
---

# Terraform conventions for the SI lab

Clones VMs from the Packer templates and hands each one to PowerShell. DC01 and
SRV01 come from the Windows Server 2025 template, CL01 from the Windows 11 one. Terraform owns
the VM shape — CPU, memory, disks, NICs, VLAN tags, VM IDs — and nothing inside the
guest.

## Layout

All Terraform lives in `terraform/`, as a flat root configuration with one file per
concern (`providers.tf`, `variables.tf`, `network.tf`, `vm-dc01.tf`, …). No modules
until there is a second environment that actually needs them — see the
simplest-thing-that-works rule in `PLAN.md`.

State is local and gitignored, as is `terraform.tfvars`. Every variable carrying a
secret is marked `sensitive = true`. Resource and variable naming and VM tags follow
`docs/conventions.md` — defer to it.

## Constraints from PLAN.md

- **bpg/proxmox only.** Telmate/proxmox was rejected for state drift on clone
  operations. Do not switch providers and do not copy Telmate examples — the resource
  names and arguments differ and will silently not do what the example says.
- **Addresses come from `docs/network-design.md`.** Every static IP, VLAN ID, gateway
  and VM ID is already decided there. Never invent one; if the design is wrong, change
  the design first.
- **Guest configuration is not Terraform's job.** No chains of `remote-exec` doing AD
  work. Terraform's last act is bringing the VM up with the first-boot PowerShell in
  place; `powershell/` takes it from there.
- **The topology is fixed:** DC01, SRV01, CL01 and the firewall. Adding a VM is a
  change to `PLAN.md` first.
- **The OPNsense VM lives here too**, cloned from `tpl-opnsense-v1` (`packer/opnsense.pkr.hcl`)
  the same as the three Windows guests — see the zero-touch decision in `PLAN.md`, which
  superseded the earlier manual/ISO-boot arrangement. Its one remaining exception to the
  rules on this page: the trunk `network_device` carries VLANs 10/20/30 tagged, so it sets
  no `vlan_id` of its own.
- **This root is applied in two stages.** The firewall VM comes up before the Windows
  guests are worth starting: until it routes there is no gateway, no DHCP and no DNS
  path. A single blind `apply` of everything is not the intended use.

- **This configuration cannot be applied.** There is no Proxmox host, so `plan` and
  `apply` are unavailable during development, possibly ever. `terraform validate` with
  `-backend=false` is the real check — it will not catch a wrong VM ID, a missing
  template or a bad datastore name. Pin bpg/proxmox to an exact version.
- **`fmt`, `init` and `validate` run locally now** — the `terraform` CLI is installed
  (2026-09-12). Run them before pushing rather than finding out from a red CI run.
  This doesn't change the point above: `plan`/`apply` still have no host to run
  against.

## Conventions

- One `proxmox_virtual_environment_vm` per host, with an explicit `vm_id` from the
  address table so a rebuild lands on the same ID every time.
- Every Windows guest pins an explicit MAC address, taken from `docs/conventions.md`.
  A generated MAC would change on rebuild and silently miss its DHCP reservation, leaving
  the guest unreachable with nothing in a plan or a validate run to indicate why.
- Every `network_device` gets an explicit `vlan_id`. An untagged NIC is a bug, not a
  default — with exactly one exception: the OPNsense trunk NIC carries VLANs 10, 20 and
  30 tagged and therefore sets no `vlan_id` of its own. It is commented as deliberate in
  `vm-opnsense.tf`. Do not "fix" it, and do not let it become a precedent for any other
  guest.
- Read the `plan` before every `apply`. A plan proposing to replace a VM you did not
  intend to touch usually means the base template changed underneath the state.
- Commit `.terraform.lock.hcl` — Terraform asks for this itself on first `init`, and
  it's the same "pin everything exactly" discipline as every version constraint in
  this repo.

## Gotchas

- `.gitignore`'s `*.tfvars` swallows `example.tfvars` too, same as
  `*.pkrvars.hcl`/`example.pkrvars.hcl` in `packer-windows`. Needs its own
  `!example.tfvars` line right after, or the committed example silently never
  stages.
- Not every root needs a `sensitive = true` variable — this root's Milestone 4
  scaffold (node, datastores, VLAN IDs) has no secrets in it at all, since
  `provider "proxmox" {}` picks up `PROXMOX_VE_ENDPOINT`/`PROXMOX_VE_API_TOKEN`
  natively and never needs them as declared variables. Don't invent a sensitive
  variable just to have one — mark one `sensitive` only once a real secret
  variable exists (the WinRM passwords Milestone 5 adds, for instance).
