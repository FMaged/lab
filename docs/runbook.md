# Runbook: bare metal to a working domain

Ordered, end to end. Each section is a placeholder until its milestone in
`TASKS.md` lands — filled in with the actual commands and any gotchas hit while
doing it, not written speculatively ahead of the work.

## 1. Proxmox host install

**Never executed.** Every step below is what `proxmox/answer.toml` and
`proxmox/first-boot-hook.sh` are written to do — there is no host to run them
against yet. See the execution status decision in PLAN.md, and the zero-touch
decision for why this section describes an unattended install rather than a
person clicking through one.

1. `cp example.env .env`, then `scripts/init-env.sh` to generate every locally
   generatable credential, including `PROXMOX_ROOT_PASSWORD`/`_HASH`. Load it:
   `set -a; . ./.env; set +a`.
2. Download the Proxmox VE installer ISO. `scripts/prepare-proxmox-iso.sh
   <source.iso> <output.iso>` renders `proxmox/answer.toml` from `.env` and
   calls `proxmox-auto-install-assistant prepare-iso` to embed the rendered
   answer file and `proxmox/first-boot-hook.sh` into `<output.iso>`. Both the
   rendered answer file and any prepared ISO are gitignored — never commit
   either.
3. Get `<output.iso>` onto the rented server and boot it. The exact delivery
   mechanism (virtual media, a provider's own custom-ISO upload) is Milestone 8
   task 1's job to confirm once a specific product is chosen.
4. The install runs unattended per `proxmox/answer.toml` — German keyboard and
   timezone, static address `10.10.10.2/24` on the Management VLAN, gateway
   `10.10.10.1` (`docs/network-design.md`) — and reboots on its own when done.
5. On first real boot, `proxmox/first-boot-hook.sh` runs exactly once
   (Proxmox's own `proxmox-first-boot` package guarantees this), mints one API
   token each for Terraform and Packer, per the secrets decision in PLAN.md,
   and writes both — already shaped as `.env` lines — to
   `/root/proxmox-api-tokens.txt`.
6. Set the host firewall rule restricting the web UI to your own address
   **before** relying on anything past this point (Milestone 8 task 4) — this
   section only gets the host installed and reachable over SSH, not secured
   against the open internet.
7. SSH in as `root` with `PROXMOX_ROOT_PASSWORD` from `.env`, copy the two
   lines out of `/root/proxmox-api-tokens.txt` into `.env`, delete the file on
   the host, and reload `.env`.

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

1. Upload the two Windows installation ISOs, the VirtIO driver ISO, and the
   OPNsense installer ISO (decompressed from its `.iso.bz2` download) to the
   Proxmox `local` datastore (or whatever `iso_datastore` is set to), named
   exactly as `docs/conventions.md` specifies — `win-server-2025-de.iso`,
   `win-11-pro-de.iso`, `virtio-win-<version>.iso`, `OPNsense-26.7-dvd-amd64.iso`.
2. `.env` should already be filled in from section 1 — that covers the Proxmox
   URL, both its tokens, and every guest and OPNsense credential this section
   needs. Separately, copy `packer/example.pkrvars.hcl` to
   `packer/packer.auto.pkrvars.hcl` (gitignored) and set the node, datastores
   and the four ISO checksums — those are not secrets and do not belong in
   `.env`. Never commit either filled-in file.
3. From `packer/`: `packer init .` (downloads the pinned Proxmox and
   Windows-Update plugins), then `packer build .`. All three templates build
   from one invocation — two build blocks (`windows-templates` and
   `opnsense-template`) across the sources in the directory, not one shared
   block, but `packer build .` with no `-only` flag still runs every source in
   both.
4. Watch each build reach its communicator — WinRM for the two Windows
   sources (the point the packer-windows skill calls "finished"), SSH for
   OPNsense. If a Windows build hangs first, the most likely causes, in order:
   the VirtIO driver isn't at the drive letter the answer file expects (see
   the multi-letter hedge in both `autounattend-*.xml`), the image-index name
   doesn't match the real ISO (`docs/conventions.md`'s residual unknown,
   flagged since the Windows 11 SPIKE), or the bootstrap password in the
   answer file and the source block's `winrm_password` have drifted out of
   sync. If the OPNsense build hangs, see `packer/opnsense.pkr.hcl`'s own
   comments first — its `boot_command` is the single least-verified artifact
   in the whole project (PLAN.md's zero-touch SPIKE), and the config-carrier
   device name (guessed as `cd1`) is the most likely wrong guess.
5. On success, confirm all three templates exist in the Proxmox UI:
   `tpl-winsrv2025-de-v1` (9000), `tpl-win11-de-v1` (9001) and
   `tpl-opnsense-v1` (9002), each tagged `lab` plus its role tag. Confirm the
   QEMU guest agent is installed inside each *Windows* template specifically —
   OPNsense has none, deliberately (`agent { enabled = false }` on that guest).
   A Windows template without the agent does not fail the next apply — it
   makes Terraform wait for a ping that never arrives until the step times
   out. `install-guest-tools.ps1` now fails the build on a non-zero installer
   exit code, so this check should be a formality; confirm it anyway, once.
6. Re-running `packer build .` after a change always produces a *new* numbered
   template (`-v2`, `-v3`, …) per `docs/conventions.md` — it never overwrites
   `-v1` in place. `terraform/` clones by template *name*, so bumping the version
   is a Terraform change too — the old template stays until nothing references it.

## 3. OPNsense setup

**Never executed.** Every step in 3a and 3b is written from the design docs and
validated where a validator exists; none of it has run against a real firewall.
See the execution status decision in PLAN.md.

### 3a. The template's baked-in configuration

There is no manual bootstrap any more — the zero-touch decision in PLAN.md
superseded it. Interface assignment, VLAN devices and addressing are all
already in `tpl-opnsense-v1` by the time section 2's `packer build .` finishes,
set by `packer/files/config.xml` via the live-image config importer, not typed
by a person after the VM exists. If a setting here turns out wrong, the fix is
that file (and a new template version), never a click in the web UI.

Nothing to do in this section by hand. If it needs checking:

- The interface assignment (WAN on `vtnet0`, the three VLANs on `vtnet1` as
  `opt1`/`opt2`/`opt3`) and every address are `packer/files/config.xml`'s job —
  compare them against `docs/network-design.md` there, not on a live system.
- The one credential this section still involves is the root password, and
  even that is not typed anywhere at runbook time — `scripts/init-env.sh`
  generated it into `.env` back in section 1, and
  `packer/opnsense.pkr.hcl`'s last provisioner rotates it into the template
  during the build.
- The API key and secret `opnsense/`'s Terraform provider authenticates with
  are generated the same way, baked into the template the same build, and
  already sit in `.env` as `OPNSENSE_API_KEY`/`OPNSENSE_API_SECRET` — nothing
  here waits on a step that hasn't happened yet, unlike the old bootstrapping
  order this section used to describe.

### 3b. Clone the firewall, then apply DHCP, firewall and NAT

From `terraform/`, create **only the firewall** first:

```
terraform apply -target=proxmox_virtual_environment_vm.opnsense
```

The `-target` is not optional. This root defines all four guests, and a plain
`apply` here would build the three Windows machines too — before the network
they need exists, so each would boot with no address and Terraform's WinRM
handoff would hang waiting on an address nothing is serving yet.

1. `terraform init && terraform apply` in `opnsense/` — creates the Clients
   DHCP scope, the Servers reservations, the aliases, every filter rule and
   the outbound NAT rule. No VLAN devices to create here any more (3a) — this
   root only ever reaches settings the API actually exposes.
2. Verify: from a host on each VLAN, confirm it can reach its gateway and (for
   Clients) that it received a DHCP lease with DC01 as its DNS server. There is
   no DC01 yet at this point, so the DNS server it hands out is an address that
   does not answer — that is expected here and fixed by section 4.

Re-running `terraform apply` in `opnsense/` after a change is safe and expected
— unlike the Packer templates, this root's resources are meant to be updated in
place, not replaced.

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
in the `.env` loaded back in section 1:

| Variable | Value |
| --- | --- |
| `TF_VAR_local_admin_password` | must equal `PKR_VAR_local_admin_password` — Packer baked it into both templates and Terraform's WinRM connection authenticates with it |
| `TF_VAR_domain_admin_password` | domain administrator password: SRV01 and CL01's join, and reused as DC01's own local Administrator password just before promotion (see step 3) |
| `TF_VAR_dsrm_recovery_password` | Directory Services Restore Mode password, for DC01's `Install-ADDSForest` call only |

None has a default, because every one is a credential. Terraform passes all three
as command-line arguments to each guest's Bootstrap script — DC01 gets all three,
SRV01 and CL01 the first two.

1. `terraform apply` in `terraform/`, targeted at just DC01 first
   (`-target=proxmox_virtual_environment_vm.dc01`) rather than all four guests
   at once — DC01 has to exist and be reachable before SRV01/CL01's own applies
   would mean anything, since they join a domain DC01 hasn't created yet.
2. Proxmox clones the template, boots DC01, and it picks up its DHCP
   reservation (`10.10.20.10` — `opnsense/dhcp.tf`). Terraform's WinRM
   connection waits on exactly that address; if the reservation is missing or
   the MAC doesn't match `docs/conventions.md`, this is where it hangs.
   Two other hangs look identical here and are worth ruling out in order: the
   guest agent missing from the template (section 2 step 5), and the clone's
   disk disagreeing with the template's — `terraform/` declares 80 GB for the
   servers and 64 GB for the client to match the two Packer builds, and a clone
   can grow a disk but never shrink one.
3. Terraform uploads `powershell/` and runs `Bootstrap-DC01.ps1` once. From
   here the guest drives itself across two reboots without Terraform's
   involvement — see the reboot decision in `PLAN.md`:
   - **Addressing** — renames the guest to `DC01`, replaces its DHCP address
     with the static `10.10.20.10`, and points DNS at OPNsense (`10.10.20.1`)
     since DC01 is not authoritative for itself yet. No reboot of its own —
     falls straight through into the next phase, so the recovery password
     never has to survive one (see the credential-ordering decision in
     PLAN.md).
   - **Promotion** — installs AD DS, resets the local Administrator's
     password to `domain_admin_password` (so it carries over into becoming
     the domain Administrator's password), then calls `Install-ADDSForest`
     for `ad.silab.internal` / `SILAB` at the 2025 functional level. This
     call reboots the guest on its own — **the first of DC01's two reboots**.
     A scheduled task (`SILab-Resume-DC01`, `AtStartup`, `SYSTEM`) resumes
     `Bootstrap-DC01.ps1` automatically after it.
   - **Site rename, OU tree and groups, baseline GPOs** — all three run in
     the same resumed invocation, since none of them need a credential or a
     reboot: renames the default site to `SILAB-Lab`, points DC01's DNS at
     itself, creates the `SILAB` OU tree and the two groups from
     `docs/ad-design.md`, then the three baseline GPOs. The scheduled task is
     unregistered at the very end — there is nothing left to resume to.
4. Confirm the transcript for each invocation under
   `C:\ProgramData\SILab\Logs\Bootstrap-DC01-<timestamp>.log` on DC01, and the
   current phase in `C:\ProgramData\SILab\phase.json`. A guest sitting
   unreachable is expected between step 3's promotion phase and its reboot
   completing — check `Get-ScheduledTask -TaskName 'SILab-Resume-DC01'` exists
   if it looks stuck rather than assuming a hang.
5. Confirm DC01 now answers on `10.10.20.10` *statically* — the DHCP
   reservation was only ever how it got there the first time — and that
   `docs/ad-design.md`'s forest, OU tree and GPOs are all present. Section 5's
   closing step runs the actual health check for both this section and the
   next.

## 5. SRV01 and CL01 — join the domain

**Never executed.** Depends on section 4 being complete — a domain that
doesn't exist yet has nothing to join.

1. `terraform apply` in `terraform/` again, this time for the remaining two
   guests (or the whole root — DC01's apply is now a no-op). Both can go in
   the same apply; neither depends on the other, only on DC01.
2. Each picks up its own DHCP reservation (`10.10.20.11` for SRV01,
   `10.10.30.50` for CL01) and Terraform runs its own Bootstrap script once:
   - **SRV01** (`Bootstrap-SRV01.ps1`) — an addressing phase first (static
     `10.10.20.11`, DNS pointed at DC01), no reboot, falling straight through
     into the join phase in the same invocation. The join
     (`Add-Computer -NewName 'SRV01' ... -OUPath 'Computers/Servers'`) waits
     for DC01 to answer on LDAP first — booting before DC01 finishes
     promoting is a normal race, not a failure — then consumes
     `domain_admin_password` and reboots on its own. A scheduled task
     (`SILab-Resume-SRV01`) resumes and unregisters itself once the join has
     completed.
   - **CL01** (`Bootstrap-CL01.ps1`) — no addressing phase at all, since CL01
     stays on DHCP permanently. Waits for DC01 the same way, then joins
     directly with `-NewName 'CL01' -OUPath 'Computers/Workstations'`,
     reboots, and its own scheduled task (`SILab-Resume-CL01`) unregisters
     itself afterward.
3. Confirm both show up as domain-joined computer objects in the OUs
   `docs/ad-design.md` specifies (`Computers/Servers` for SRV01,
   `Computers/Workstations` for CL01), and that CL01's logon screen shows the
   Workstation Baseline GPO's banner — the one visible proof point the whole
   lab has been building toward since Milestone 1. As with DC01, a transcript
   for each invocation lives under `C:\ProgramData\SILab\Logs` on the guest
   in question, and a phase stuck between the join call and its reboot
   completing looks unreachable rather than hung.
4. Close both sections by copying `powershell/Test-SILab.ps1` to DC01 (or any
   domain member with RSAT) and running it: `.\Test-SILab.ps1`. It is
   read-only, prints one `[PASS]`/`[FAIL]` line per row of
   `docs/ad-design.md` and `docs/network-design.md`, and exits non-zero if
   anything is missing — the actual verification step for every claim in
   sections 4 and 5, not just a suggestion to look around by hand.

## 6. Full rebuild, start to finish

*(Milestone 8 — not started. Will cover: tearing everything down and replaying
sections 1–5 in order from a clean host, as the final proof the repo is complete.)*
