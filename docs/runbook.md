# Runbook: bare metal to a working domain

Ordered, end to end. Each section is a placeholder until its milestone in
`TASKS.md` lands — filled in with the actual commands and any gotchas hit while
doing it, not written speculatively ahead of the work.

## 1. Proxmox host install

**Never executed.** Every step below is what `proxmox/answer.toml` and
`proxmox/first-boot-hook.sh` are written to do, and the last of it is the
first stage `scripts/host-runner.sh` runs — there is no host to run any of it
against yet. See the execution status decision in PLAN.md.

1. On your own machine: `cp example.env .env`, then `scripts/init-env.sh` to
   generate every locally generatable credential, including
   `PROXMOX_ROOT_PASSWORD`/`_HASH`.
2. Download the Proxmox VE installer ISO. `set -a; . ./.env; set +a`, then
   `scripts/prepare-proxmox-iso.sh <source.iso> <output.iso>` renders
   `proxmox/answer.toml` from `.env` and calls `proxmox-auto-install-assistant
   prepare-iso` to embed the rendered answer file and
   `proxmox/first-boot-hook.sh` into `<output.iso>`. Both the rendered answer
   file and any prepared ISO are gitignored — never commit either.
3. Get `<output.iso>` onto the rented server and boot it (Milestone 8 task 1
   confirms the exact delivery mechanism once a specific product is chosen).
4. The install runs unattended per `proxmox/answer.toml` — German keyboard and
   timezone, `source = "from-dhcp"` for whatever address the provider's own
   uplink hands out, since no VLAN exists yet to put a static one on (the
   host-network SPIKE, PLAN.md) — and reboots on its own when done.
5. On first real boot, `proxmox/first-boot-hook.sh` runs exactly once
   (Proxmox's own `proxmox-first-boot` package guarantees this) and mints one
   API token each for Terraform and Packer, per the secrets decision in
   PLAN.md, writing both to `/root/proxmox-api-tokens.txt`. Nobody copies
   these out by hand any more — `scripts/host-runner.sh` merges them into
   `.env` itself and deletes the file, as its own first real stage.
6. Set the host firewall rule restricting the web UI to your own address
   **before** relying on anything past this point (Milestone 8 task 12) — this
   section only gets the host installed and reachable over SSH, not secured
   against the open internet.

From here, `scripts/deploy.sh <host-address>` (run from your own machine) does
everything else in this runbook — sections 2 through 5 below describe what it
does and what to check if a stage stalls, not commands to type by hand.

**If it stops:** a hang before the first reboot usually means
`proxmox/answer.toml`'s `disk-list = ["sda"]` doesn't match the real server's
boot disk — a residual unknown flagged in that file; confirm the actual device
name with the provider first. A reboot with nothing in
`/root/proxmox-api-tokens.txt` means the first-boot hook failed; check
`journalctl -u proxmox-first-boot` for why. Unlike OPNsense's build (section
2), the SPIKE behind this section found nothing in the Proxmox install that
needed a manual fallback — a genuine stall here is a bug to fix in
`proxmox/answer.toml` or the hook script, not a step to do by hand.

## 2. Packer image build

**Never executed.** Every step below is validated (`packer fmt`/`init`/`validate`,
locally and in CI) but has never run against a real Proxmox host — there is no
host yet. See the execution status decision in PLAN.md; this note comes out the
moment a real build runs.

`scripts/host-runner.sh` runs this section as two of its own stages, both
skipped automatically if their result already exists:

1. **Trust `pve-root-ca`, install Terraform and Packer, build `vmbr1`/`vmbr2`,
   merge the tokens.** Terraform 1.16.1 and Packer 1.16.0 are downloaded and
   checked against HashiCorp's own signed `SHA256SUMS`, never a package
   repository. `vmbr1` (the VLAN 10/20/30 trunk) and `vmbr2` (a disposable
   network for the build VMs, since OPNsense doesn't exist yet to route
   anything — the host-network SPIKE, PLAN.md) are created here, with
   `dnsmasq` serving `vmbr2`.
2. **Download every ISO on the host, then build.** The two Windows images and
   the VirtIO driver ISO are downloaded by Proxmox itself
   (`iso_download_pve`) straight from the URLs in
   `packer/packer.auto.pkrvars.hcl` (copy `packer/example.pkrvars.hcl` there
   first and fill in the node, datastores and four ISO URLs/checksums — not
   secrets, so this file travels with `scripts/deploy.sh`, never through
   `.env`). OPNsense ships as `.iso.bz2`, which Packer cannot decompress, so
   the runner downloads and decompresses that one itself before calling
   `packer build .`. Any template whose VMID already exists is skipped, via
   `packer build -only=...` — a re-run after a partial failure never rebuilds
   what already succeeded.

**If it stalls:** watch which communicator a build is waiting on — WinRM for
the two Windows sources (the point the packer-windows skill calls
"finished"), SSH for OPNsense. If a Windows build hangs first, the most
likely causes, in order: the VirtIO driver isn't at the drive letter the
answer file expects (see the multi-letter hedge in both `autounattend-*.xml`),
the image-index name doesn't match the real ISO (`docs/conventions.md`'s
residual unknown, flagged since the Windows 11 SPIKE), or the bootstrap
password in the answer file and the source block's `winrm_password` have
drifted out of sync. If the OPNsense build hangs, see
`packer/opnsense.pkr.hcl`'s own comments first — its `boot_command` is the
single least-verified artifact in the whole project (PLAN.md's zero-touch
SPIKE), and the config-carrier device name (guessed as `cd1`) is the most
likely wrong guess.

On success, all three templates exist in the Proxmox UI:
`tpl-winsrv2025-de-v1` (9000), `tpl-win11-de-v1` (9001) and `tpl-opnsense-v1`
(9002), each tagged `lab` plus its role tag. A Windows template without the
QEMU guest agent does not fail this step — it makes the *next* one wait on a
ping that never arrives. Re-running `packer build .` after a change always
produces a *new* numbered template (`-v2`, `-v3`, …) per
`docs/conventions.md` — it never overwrites `-v1` in place; `terraform/`
clones by template *name*, so bumping the version is a Terraform change too.

## 3. OPNsense setup

**Never executed.** Every step in 3a and 3b is written from the design docs and
validated where a validator exists; none of it has run against a real firewall.
See the execution status decision in PLAN.md.

### 3a. The template's baked-in configuration

There is no manual bootstrap any more — the zero-touch decision in PLAN.md
superseded it. Interface assignment, VLAN devices and addressing are all
already in `tpl-opnsense-v1` by the time section 2's build finishes, set by
`packer/files/config.xml` via the live-image config importer, not typed by a
person after the VM exists. If a setting here turns out wrong, the fix is
that file (and a new template version), never a click in the web UI.

Nothing to do in this section by hand. If it needs checking:

- The interface assignment (WAN on `vtnet0`, the three VLANs on `vtnet1` as
  `opt1`/`opt2`/`opt3`) and every address are `packer/files/config.xml`'s job —
  compare them against `docs/network-design.md` there, not on a live system.
- The root password is generated by `scripts/init-env.sh` and rotated into the
  template by `packer/opnsense.pkr.hcl`'s last provisioner, never typed
  anywhere at runbook time.
- The API key and secret `opnsense/`'s Terraform provider authenticates with
  are generated the same way, baked into the template the same build, and
  already sit in `.env` as `OPNSENSE_API_KEY`/`OPNSENSE_API_SECRET`.

### 3b. Clone the firewall, then apply DHCP, firewall and NAT

`scripts/host-runner.sh`'s next stage does this: `terraform apply
-target=proxmox_virtual_environment_vm.opnsense` first (not optional — this
root defines all four guests, and a plain `apply` would start the three
Windows machines before the network they need exists), then `terraform init
&& terraform apply` in `opnsense/` — creating the Clients DHCP scope, the
Servers reservations, the aliases, every filter rule (including the four
narrow rules letting the Proxmox host itself reach each guest's WinRM and
OPNsense's own API — task 6, PLAN.md) and the outbound NAT rule. Both applies
are skipped if the firewall guest already exists.

**If it stalls:** verify from a host on each VLAN that it can reach its
gateway and, for Clients, that it received a DHCP lease with DC01 as its DNS
server — there is no DC01 yet at this point, so that address not answering is
expected here, not a fault, and gets fixed by section 4.

**CI:** the Terraform job in `.github/workflows/validate.yml` already matrixes
over both `terraform/` and `opnsense/` (added in Milestone 2, before either root
held anything), so no workflow change was needed to cover this milestone's new
resources — confirmed by pushing this milestone's real code and watching both
matrix legs go green, then deliberately breaking one resource on a throwaway
branch and watching that leg go red before reverting.

## 4. DC01 — domain controller

**Never executed.** Depends on section 3 being fully done first — no gateway, no
DHCP reservation and no DNS path exist until the firewall is cloned and its
`opnsense/` apply has run. Also depends on three guest passwords, all already
in `.env`:

| Variable | Value |
| --- | --- |
| `TF_VAR_local_admin_password` | must equal `PKR_VAR_local_admin_password` — Packer baked it into both templates and Terraform's WinRM connection authenticates with it |
| `TF_VAR_domain_admin_password` | domain administrator password: SRV01 and CL01's join, and reused as DC01's own local Administrator password just before promotion (see below) |
| `TF_VAR_dsrm_recovery_password` | Directory Services Restore Mode password, for DC01's `Install-ADDSForest` call only |

None has a default, because every one is a credential.

`scripts/host-runner.sh`'s next stage: `terraform apply
-target=proxmox_virtual_environment_vm.dc01` (skipped if DC01 already
exists) clones the template, boots DC01 onto its DHCP reservation
(`10.10.20.10` — `opnsense/dhcp.tf`), uploads `powershell/`, and launches
`Bootstrap-DC01.ps1` **detached** via `Start-SILabDetached` — the provisioner
returns almost at once rather than waiting on a script that reboots twice
(the orchestration SPIKE, PLAN.md). From here the guest drives itself across
both reboots with no further Terraform involvement:

- **Addressing** — renames the guest to `DC01`, replaces its DHCP address
  with the static `10.10.20.10`, and points DNS at OPNsense (`10.10.20.1`)
  since DC01 is not authoritative for itself yet. No reboot of its own.
- **Promotion** — installs AD DS, resets the local Administrator's password
  to `domain_admin_password` (carrying it over as the domain Administrator's
  password), then calls `Install-ADDSForest` for `ad.silab.internal` /
  `SILAB` at the 2025 functional level — **the first of DC01's two reboots**.
  `SILab-Resume-DC01` (`AtStartup`, `SYSTEM`, no credential in its own
  definition) resumes automatically after it.
- **Site rename, OU tree and groups, baseline GPOs** — all run in the same
  resumed invocation, no credential or reboot needed for any of them, ending
  by unregistering the resume task.

The runner then polls DC01's own `C:\ProgramData\SILab\phase.json` (via
`terraform/wait-for-guests.tf`'s `wait_dc01` resource, repeatedly
`-replace`d) until it reports phase 5 — the same file the resume mechanism
already relies on, not a new signal.

**If it stalls:** confirm the transcript for each invocation under
`C:\ProgramData\SILab\Logs\Bootstrap-DC01-<timestamp>.log` on DC01, and the
current phase in `phase.json` directly, rather than guessing from
reachability alone — a guest mid-reboot looks identical to a hung one. Check
`Get-ScheduledTask -TaskName 'SILab-Resume-DC01'` exists if it looks stuck.
Two hangs before any of this look identical to a missing DHCP reservation:
the guest agent missing from the template (section 2), and the clone's disk
disagreeing with the template's (`terraform/` declares 80 GB to match the
Packer build; a clone can grow a disk but never shrink one).

## 5. SRV01 and CL01 — join the domain

**Never executed.** Depends on section 4 being complete — a domain that
doesn't exist yet has nothing to join.

`scripts/host-runner.sh`'s last two stages: `terraform apply` for the
remaining two guests (skipped for whichever already exists), then the same
detached-launch-and-poll pattern as DC01, against `wait_srv01`
(phase 2) and `wait_cl01` (phase 1):

- **SRV01** (`Bootstrap-SRV01.ps1`) — an addressing phase first (static
  `10.10.20.11`, DNS pointed at DC01), no reboot, falling straight through
  into the join phase. The join (`Add-Computer -NewName 'SRV01' ...
  -OUPath 'Computers/Servers'`) waits for DC01 to answer on LDAP first —
  booting before DC01 finishes promoting is a normal race, not a failure —
  then consumes `domain_admin_password` and reboots on its own.
  `SILab-Resume-SRV01` resumes and unregisters itself once the join
  completes.
- **CL01** (`Bootstrap-CL01.ps1`) — no addressing phase at all, since CL01
  stays on DHCP permanently. Waits for DC01 the same way, joins directly with
  `-NewName 'CL01' -OUPath 'Computers/Workstations'`, reboots, and
  `SILab-Resume-CL01` unregisters itself afterward.

Once both report their terminal phase, the runner's last stage runs
`Test-SILab.ps1` on DC01 (`terraform_data.run_health_check`) — read-only,
prints one `[PASS]`/`[FAIL]` line per row of `docs/ad-design.md` and
`docs/network-design.md`, and its own exit code becomes `scripts/deploy.sh`'s
exit code. A pass scrubs every secret from the host automatically
(`scripts/scrub-host.sh`); a fail keeps everything in place for a re-run and
prints the exact command to scrub by hand before releasing the server anyway
— see Milestone 8 task 13.

**If it stalls:** confirm both show up as domain-joined computer objects in
the OUs `docs/ad-design.md` specifies, and that CL01's logon screen shows the
Workstation Baseline GPO's banner — the one visible proof point the whole lab
has been building toward since Milestone 1. A transcript for each invocation
lives under `C:\ProgramData\SILab\Logs` on the guest in question; a phase
stuck between the join call and its reboot completing looks unreachable
rather than hung, the same as DC01.

## 6. Full rebuild, start to finish

*(Milestone 8 — not started. Will cover: tearing everything down and replaying
sections 1–5 in order from a clean host, as the final proof the repo is complete.)*
