# Runbook: bare metal to a working domain

Ordered, end to end. Each section is a placeholder until its milestone in
`TASKS.md` lands — filled in with the actual commands and any gotchas hit while
doing it, not written speculatively ahead of the work.

## 1. Proxmox host install

*(Milestone 2 — not started. Will cover: ISO install, network/VLAN bridge setup
matching `docs/hardware.md`, and confirming the host is reachable at 10.10.10.2.)*

## 2. Packer image build

**Never executed.** Every step below is validated (`packer fmt`/`init`/`validate`,
locally and in CI) but has never run against a real Proxmox host — there is no
host yet. See the execution status decision in PLAN.md; this note comes out the
moment a real build runs.

1. Upload the two installation ISOs and the VirtIO driver ISO to the Proxmox
   `local` datastore (or whatever `iso_datastore` is set to), named exactly as
   `docs/conventions.md` specifies — `win-server-2025-de.iso`,
   `win-11-pro-de.iso`, `virtio-win-<version>.iso`.
2. Copy `packer/example.pkrvars.hcl` to `packer/packer.auto.pkrvars.hcl`
   (gitignored) and fill in the real Proxmox URL, node, API token, ISO
   checksums and `local_admin_password` — or set the equivalent `PKR_VAR_*`
   environment variables instead. Never commit the filled-in file.
3. From `packer/`: `packer init .` (downloads the pinned Proxmox and
   Windows-Update plugins), then `packer build .`. Both sources build from one
   `packer build .` invocation, since they share the `windows-templates` build
   block — there is no way to build just one without commenting out the other's
   `source` entry in `build.pkr.hcl`.
4. Watch for the build reaching the WinRM communicator — this is the point the
   packer-windows skill calls "finished" for the unattended-install half. If it
   hangs before then, the most likely causes, in order: the VirtIO driver isn't
   at the drive letter the answer file expects (see the multi-letter hedge in
   both `autounattend-*.xml`), the image-index name doesn't match the real ISO
   (`docs/conventions.md`'s residual unknown, flagged since the Windows 11 SPIKE),
   or the bootstrap password in the answer file and the source block's
   `winrm_password` have drifted out of sync.
5. On success, confirm both templates exist in the Proxmox UI: `tpl-winsrv2025-de-v1`
   and `tpl-win11-de-v1`, VM IDs 9000 and 9001, tagged `lab` plus their role tag.
6. Re-running `packer build .` after a change always produces a *new* numbered
   template (`-v2`, `-v3`, …) per `docs/conventions.md` — it never overwrites
   `-v1` in place, even before Milestone 5 has anything cloning from it yet.

## 3. OPNsense setup

*(Milestone 4 — not started. Will cover: applying the VLAN/interface/DHCP/firewall
config decided by the Milestone 1 SPIKE, and verifying each VLAN routes.)*

## 4. DC01 — domain controller

*(Milestone 5 — not started. Will cover: `terraform apply` for DC01, then running
the promotion PowerShell against `docs/ad-design.md`, and verifying AD DS/DNS come
up.)*

## 5. SRV01 and CL01 — join the domain

*(Milestone 6 — not started. Will cover: `terraform apply` for both, the domain-join
PowerShell, and confirming the Workstation Baseline GPO's logon banner appears on
CL01.)*

## 6. Full rebuild, start to finish

*(Milestone 7 — not started. Will cover: tearing everything down and replaying
sections 1–5 in order from a clean host, as the final proof the repo is complete.)*
