# Runbook: bare metal to a working domain

Ordered, end to end. Each section is a placeholder until its milestone in
`TASKS.md` lands — filled in with the actual commands and any gotchas hit while
doing it, not written speculatively ahead of the work.

## 1. Proxmox host install

*(Milestone 8 — not started. Will cover: ISO install, network/VLAN bridge setup
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
   Also confirm the QEMU guest agent is installed inside each template, not just
   that the build succeeded. Every guest sets `agent { enabled = true }`, so a
   template without the agent does not fail the next apply — it makes Terraform
   wait for a ping that never arrives until the step times out.
   `install-guest-tools.ps1` now fails the build on a non-zero installer exit
   code, so this check should be a formality; confirm it anyway, once.
6. Re-running `packer build .` after a change always produces a *new* numbered
   template (`-v2`, `-v3`, …) per `docs/conventions.md` — it never overwrites
   `-v1` in place. `terraform/` clones by template *name*, so bumping the version
   is a Terraform change too — the old template stays until nothing references it.

## 3. OPNsense setup

**Never executed.** Every step in 3a and 3b is written from the design docs and
validated where a validator exists; none of it has run against a real firewall.
See the execution status decision in PLAN.md.

### 3a. Manual bootstrap

The manual/code boundary is interface assignment and addressing, not VLANs — see
the decision in PLAN.md. Concretely, that means this half happens in two passes:
some of it before `terraform apply` creates the VLAN devices, the rest after.

Set these before starting — step 1 already needs the first two:

| Variable | Used by | Value |
| --- | --- | --- |
| `PROXMOX_VE_ENDPOINT` | `terraform/` | the Proxmox API URL, from section 1 |
| `PROXMOX_VE_API_TOKEN` | `terraform/` | the Proxmox API token created during section 1's host install |
| `OPNSENSE_URI` | `opnsense/` | `https://` + OPNsense's Management address, `10.10.10.1` |
| `OPNSENSE_API_KEY` | `opnsense/` | the key from step 5 below |
| `OPNSENSE_API_SECRET` | `opnsense/` | the secret from step 5 below |

The two OPNsense values do not exist until step 5 creates them. That is the
bootstrapping problem this section exists to solve.

**Before `terraform apply` for `terraform/vm-opnsense.tf`:**

1. Attach the OPNsense installation ISO to the `local` datastore first, as
   `local:iso/opnsense.iso` — the VM won't boot without it. Then, from
   `terraform/`, create **only the firewall**:

   ```
   terraform apply -target=proxmox_virtual_environment_vm.opnsense
   ```

   The `-target` is not optional. This root defines all four guests, and a plain
   `apply` here would build the three Windows machines too — before the network
   they need exists, so each would boot with no address and Terraform's WinRM
   handoff would hang waiting on an address nothing is serving yet.

**After the VM exists, before any Terraform touches `opnsense/`:**

2. Boot the VM and run the OPNsense installer from console (ZFS is fine for a
   lab; set a root password you'll actually remember, since it's what the web
   UI login uses too).
3. At the console menu, **Assign interfaces** (option 1): assign the WAN-bridge
   NIC as `wan` and note the trunk-bridge NIC's device name (e.g. `vtnet1`) —
   it stays unassigned for now. It is the VLAN devices Terraform creates from it
   in 3b that get assigned, not the raw NIC itself.
4. Confirm WAN picked up a DHCP lease from the home router (console menu or
   Interfaces > WAN in the web UI) — no action needed if it did.
5. In the web UI: **System > Settings > Administration**, enable the API.
   **System > Access > Users**, create (or use an existing account) an API
   key/secret pair. This is the literal bootstrapping problem the decision in
   PLAN.md describes — nothing in `opnsense/` can run before this exists.

**After 3b has run once and `opnsense/`'s VLAN devices exist:**

6. **Interfaces > Assignments**: assign each of the three new VLAN devices
   (`vtnet1.10`, `vtnet1.20`, `vtnet1.30`, or whatever the tag suffix renders
   as) to its own logical interface, and give each the static address from
   `docs/network-design.md`'s address table — `10.10.10.1/24`, `10.10.20.1/24`,
   `10.10.30.1/24`. Naming the assigned interfaces `MGMT`/`SERVERS`/`CLIENTS`
   (rather than the default `OPT1`/`OPT2`/`OPT3`) makes every later step, and
   every firewall rule, far easier to read.

### 3b. Code — VLANs, DHCP, firewall

Two roots, and they apply in a fixed order — `opnsense/` cannot run before 3a's
manual steps give it an API to talk to, and its own VLAN devices don't exist
for step 6 of 3a to assign until this runs once.

1. The targeted `terraform apply` in `terraform/` is already done — see 3a step 1.
   The other three guests in that root stay uncreated until section 4; they have
   nothing to boot into until this section finishes.
2. Complete 3a steps 2–5 (install, WAN assignment, enable the API).
3. `terraform init && terraform apply` in `opnsense/` — creates the three VLAN
   devices, the Clients DHCP scope, the aliases, every filter rule and the
   outbound NAT rule.
4. Complete 3a step 6 (assign each VLAN device to an interface, address it).
5. Verify: from a host on each VLAN, confirm it can reach its gateway and (for
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
DHCP reservation and no DNS path exist until the firewall is bootstrapped and
its VLAN devices are assigned and addressed. Also depends on three more
environment variables — none of the three has a default, since every one is a
credential, and none belongs in `example.tfvars` for the same reason
`PROXMOX_VE_API_TOKEN` never landed in a committed file:

| Variable | Used by | Value |
| --- | --- | --- |
| `TF_VAR_local_admin_password` | `terraform/` | matches Packer's `rotate-admin-password.ps1` value, baked into every template |
| `TF_VAR_domain_admin_password` | `terraform/` | domain administrator password — SRV01/CL01's join, and reused as DC01's own local Administrator password just before promotion (see step 3) |
| `TF_VAR_dsrm_recovery_password` | `terraform/` | Directory Services Restore Mode password — DC01's `Install-ADDSForest` call only |

Terraform passes all three as command-line arguments to each guest's
Bootstrap script (DC01 gets all three; SRV01 and CL01 get the first two only).

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
