---
name: packer-windows
description: Conventions for this repo's Packer build of the Windows Server 2025 base image — HCL layout under packer/, the proxmox-iso builder, VirtIO driver injection, the autounattend.xml that enables WinRM, and the no-sysprep rule. Use when writing or changing anything under packer/, when the user mentions Packer, .pkr.hcl, autounattend, the base image or the golden template, or when a build hangs at WinRM connect. Not for provisioning VMs from the finished template — that is Terraform, see terraform-proxmox.
---

# Packer conventions for the SI lab

Builds the single Windows Server 2025 template that every VM is cloned from. The
image stays minimal on purpose: VirtIO drivers, WinRM, updates. Anything a first-boot
PowerShell script can do instead does not belong in the image.

## Layout

All Packer code lives in `packer/`. HCL2 only (`.pkr.hcl`) — no legacy JSON. Answer
files and anything the build uploads go in `packer/files/`. Secrets arrive as
`PKR_VAR_*` environment variables; a `.pkrvars.hcl` with real values is never
committed.

Template and VM naming follow `docs/conventions.md` — defer to it, do not invent a
second scheme here.

## Constraints from PLAN.md

- **No sysprep.** The image is deliberately not generalized. Clones share a machine
  SID, which is harmless because domain join issues a fresh machine account per host
  — but nothing in this build or any later layer may depend on the SID being unique.
- **Identity comes later.** Hostname, static address and domain membership are set by
  PowerShell at first boot, not baked in. The image ships with none of them.
- **WinRM is the handoff point.** The build is finished when Packer can talk WinRM.
  Everything past that belongs to Terraform and `powershell/`.

- **This build cannot be run.** There is no Proxmox host, so `packer build` is not
  available during development and may never be. `packer fmt`, `packer init` and
  `packer validate` in CI are the only feedback — write the template to be correct on
  first read rather than iterating on build output, and pin the Proxmox plugin to an
  exact version.

## Conventions

- Target is Proxmox VE 9.2 through the `proxmox-iso` builder; the artifact is a
  Proxmox VM template, not a file on disk.
- The VirtIO driver ISO is attached as a second CD-ROM and the drivers are injected
  from `autounattend.xml`. Windows Setup cannot see a VirtIO disk without it — this is
  the most common cause of a build that dies at the disk-selection screen.
- `autounattend.xml` does three things only: partition, create the local admin, enable
  WinRM. Everything else is a provisioner.
- Provisioners are Windows PowerShell 5.1 (see the global `powershell` skill) and must
  be re-runnable, so a retry after a failed step does not need a fresh ISO boot.
- Never overwrite a template that a Terraform state still references. A changed image
  is a new template, not an edit of the old one.

## Gotchas

<!-- Empty until the build exists (Milestone 3). Anything that costs more than an hour
to work out goes here, not in a commit message. -->
