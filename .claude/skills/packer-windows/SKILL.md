---
name: packer-windows
description: Conventions for this repo's two Packer images — Windows Server 2025 Desktop Experience and Windows 11 — covering HCL layout under packer/, the proxmox-iso builder, VirtIO driver injection, the German autounattend.xml files that enable WinRM, TPM and Secure Boot for the client, and the no-sysprep rule. Use when writing or changing anything under packer/, when the user mentions Packer, .pkr.hcl, autounattend, a base image or golden template, the client image, or when a build hangs at WinRM connect. Not for provisioning VMs from the finished templates — that is Terraform, see terraform-proxmox.
---

# Packer conventions for the SI lab

Builds the two templates every VM is cloned from: Windows Server 2025 Desktop
Experience for DC01 and SRV01, and Windows 11 for CL01. Both images stay minimal on
purpose — VirtIO drivers, WinRM, updates. Anything a first-boot PowerShell script can
do instead does not belong in the image.

The two builds share everything except installation media and firmware shape. When a
change applies to both, change both in the same commit; they are a matched pair, and a
client image that drifts from the server image is how an unreproducible bug starts.

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
- **German throughout.** Both answer files set de-DE for UI, input, system and user
  locale, and Central European time. Locale is fixed at install time — changing it
  later is a rebuild, not a setting. Expect German error text when debugging.
- **Desktop Experience, not Server Core.** The GUI consoles are what produce the
  screenshots that serve as this project's evidence. Do not "optimize" the image by
  switching to Core.
- **The client needs real virtual TPM 2.0 and Secure Boot.** Windows 11 Setup enforces
  both. Give the VM the hardware rather than disabling the checks with registry edits
  copied from a forum — the supported path is the one worth demonstrating.
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

- **`packer validate` requires every variable to have a default**, unlike
  `terraform validate` — a variable with none fails immediately with "Unset
  variable", even though CI never supplies real values. Every variable in
  `packer/variables.pkr.hcl`, including the sensitive ones, has an empty-string (or
  `"none"` for an `iso_checksum`) default for exactly this reason. Real values only
  ever come from `PKR_VAR_*` at an actual build.
- `.gitignore`'s `*.pkrvars.hcl` swallows `example.pkrvars.hcl` too — it needs its
  own `!example.pkrvars.hcl` negation line right after, or the committed example
  file silently never stages.
