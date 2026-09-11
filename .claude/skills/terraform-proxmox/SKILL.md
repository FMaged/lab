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
- **The OPNsense VM lives here too**, and it is the exception to most rules on this
  page. It boots an ISO instead of cloning a template, since it has no Packer image,
  and it is bootstrapped by hand afterwards — see the bootstrap decision in `PLAN.md`.
- **This root is applied in two stages.** The firewall VM comes up and is bootstrapped
  before the Windows guests are worth starting: until it routes there is no gateway, no
  DHCP and no DNS path. A single blind `apply` of everything is not the intended use.

- **This configuration cannot be applied.** There is no Proxmox host, so `plan` and
  `apply` are unavailable during development. `terraform validate` with
  `-backend=false` in CI is the only feedback, and it will not catch a wrong VM ID, a
  missing template or a bad datastore name. Pin bpg/proxmox to an exact version.

## Conventions

- One `proxmox_virtual_environment_vm` per host, with an explicit `vm_id` from the
  address table so a rebuild lands on the same ID every time.
- Every `network_device` gets an explicit `vlan_id`. An untagged NIC is a bug, not a
  default — with exactly one exception: the OPNsense trunk NIC carries VLANs 10, 20 and
  30 tagged and therefore sets no `vlan_id` of its own. It is commented as deliberate in
  `vm-opnsense.tf`. Do not "fix" it, and do not let it become a precedent for any other
  guest.
- Read the `plan` before every `apply`. A plan proposing to replace a VM you did not
  intend to touch usually means the base template changed underneath the state.

## Gotchas

<!-- Empty until the configuration exists (Milestone 5). Anything that costs more than
an hour to work out goes here, not in a commit message. -->
