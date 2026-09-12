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
  available during development and may never be. Pin the Proxmox plugin to an
  exact version, since a version bump can't be caught by a real build here.
- **`fmt`, `init` and `validate` run locally now** — the `packer` CLI is installed
  (2026-09-11), so use it before pushing rather than guessing at HCL syntax or
  provider argument names and finding out from a red CI run. This does not change
  the point above: `packer build` still has no host to build against, so it
  remains untested until Milestone 8's proof run. `packer init` needs network
  access to GitHub for plugin downloads, which is unauthenticated-rate-limited
  (60/hr) — avoid running it back-to-back with a lot of other GitHub API calls
  from the same machine.

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
  `packer/variables.pkr.hcl` has one for exactly this reason. Real values only
  ever come from `PKR_VAR_*` at an actual build.
- **An empty-string default is not always enough**, though — confirmed the hard
  way once a real `packer` binary existed to check with. The `proxmox-iso`
  builder's own connection arguments (`proxmox_url`, `node`, `username`,
  `password`/`token`) each fail their *own* "must be specified" check against `""`,
  even though `validate` never actually connects to Proxmox. Those four variables
  use obviously-fake, non-empty placeholders instead (matching
  `example.pkrvars.hcl`'s values) — `"none"` still works fine for an
  `iso_checksum`, since that one only checks for a non-empty string with the right
  shape, not for being genuinely reachable.
- **`iso_file`/`iso_checksum` directly on the `source` block are deprecated** in
  favor of a `boot_iso { type = ...; iso_file = ...; iso_checksum = ...;
  iso_storage_pool = ... }` block. The old form still works (as a warning, not an
  error) but writing new code against an already-deprecated field on day one
  isn't worth it.
- **A generated ISO from `additional_iso_files`' `cd_files`/`cd_content` needs its
  own `iso_storage_pool`** — without it, `validate` fails with "storage_pool not
  set for storage of generated ISO from cd_files or cd_content". This is separate
  from `boot_iso`'s `iso_storage_pool`; each ISO-producing block needs the
  argument, existing-file ISOs included.
- `.gitignore`'s `*.pkrvars.hcl` swallows `example.pkrvars.hcl` too — it needs its
  own `!example.pkrvars.hcl` negation line right after, or the committed example
  file silently never stages.
